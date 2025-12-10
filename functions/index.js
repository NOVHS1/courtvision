const functions = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

const axios = require("axios");
const admin = require("firebase-admin");
const cheerio = require("cheerio");

admin.initializeApp({
  storageBucket: "courtvision-c400e.appspot.com",});
const db = admin.firestore();

const {DateTime} = require('luxon');


/* ============================================================================
   FETCH TODAY'S NBA GAMES FROM NBA.COM
============================================================================ */
exports.fetchTodayGames = onRequest(
  { timeoutSeconds: 60, memory: "1GiB" },
  async (req, res) => {
    try {
      logger.info("Running fetchTodayGames (7-day window filter)...");

      const todayET = DateTime.now().setZone("America/New_York");
      const todayStr = todayET.toISODate();

      logger.info("Today's ET date:", todayStr);

      //  NEW — create the ±3-day date window
      // ----------------------------------------------
      const startET = todayET.minus({ days: 3 }).startOf("day");
      const endET = todayET.plus({ days: 3 }).endOf("day");

      logger.info(` Filtering games from ${startET.toISODate()} → ${endET.toISODate()}`);
      // ----------------------------------------------

      // 2️Fetch NBA schedule
      const NBA_URL =
        "https://cdn.nba.com/static/json/staticData/scheduleLeagueV2.json";

      const response = await axios.get(NBA_URL, { timeout: 20000 });
      const allDates = response.data?.leagueSchedule?.gameDates;

      if (!allDates) {
        logger.error("NBA schedule malformed");
        return res.status(500).json({ error: "Schedule malformed" });
      }

      let windowGames = [];

      // 3️ Loop through ALL games — ignore unreliable gameDate
      for (const dateObj of allDates) {
        for (const g of dateObj.games) {
          
          const est = g.gameDateTimeEst || g.gameDateEst || null;
          if (!est) continue;

          const gameDate = DateTime.fromISO(est, {
            zone: "America/New_York"
          });

          // NEW — filter by 7-day window
          // ----------------------------------------------
          if (gameDate >= startET && gameDate <= endET) {
            windowGames.push(g);
          }
          // ----------------------------------------------
        }
      }

      logger.info(`Found ${windowGames.length} games in 7-day range`);

      if (windowGames.length === 0) {
        return res.json({
          message: "No games found in 7-day window",
          windowStart: startET.toISODate(),
          windowEnd: endET.toISODate()
        });
      }

      // 4️ Save to Firestore using gameId
      let saved = 0;

      for (const g of windowGames) {
        const home = g.homeTeam || {};
        const away = g.awayTeam || {};

        const docData = {
          gameId: g.gameId,
          gameCode: g.gameCode,
          status: g.gameStatusText || "scheduled",

          home: {
            name: home.teamName || "",
            triCode: home.teamTricode || "",
            score: home.score ?? 0,
          },

          away: {
            name: away.teamName || "",
            triCode: away.teamTricode || "",
            score: away.score ?? 0,
          },

          scheduledUTC: g.gameDateTimeUTC || g.gameDateTimeEst,
          //  NEW — also store EST date for easy UI filtering
          scheduledEST: g.gameDateTimeEst || g.gameDateEst,

          updatedAt: new Date().toISOString(),
        };

        await db
          .collection("nba_games")
          .doc(g.gameId.toString())
          .set(docData, { merge: true });

        saved++;
      }

      logger.info(`Saved ${saved} games to Firestore.`);

      return res.json({
        success: true,
        saved,
        windowStart: startET.toISODate(),
        windowEnd: endET.toISODate(),
        totalReturned: windowGames.length,
      });

    } catch (err) {
      logger.error("fetchTodayGames error:", err);
      return res.status(500).json({ error: "Internal error" });
    }
  }
);


// ================================================================
//   UTILITIES
// ================================================================

// Detect current NBA season
function getCurrentSeason() {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth() + 1;
  const start = m >= 10 ? y : y - 1;
  const end = start + 1;
  return `${start}-${end.toString().slice(-2)}`;
}

// Predict next season with slight boost
function projectNextSeason(current) {
  if (!current) return null;

  let out = {};
  Object.keys(current).forEach((k) => {
    if (typeof current[k] === "number") {
      out[k] = parseFloat((current[k] * 1.01).toFixed(3));
    } else {
      out[k] = current[k];
    }
  });

  ["fgPct", "threePct", "ftPct"].forEach((k) => {
    if (out[k] > 0.7) out[k] = 0.7;
    if (out[k] < 0.2) out[k] = 0.2;
  });

  return out;
}



// ================================================================
// 1. resolveNbaId — Search NBA.com for player ID
// ================================================================
exports.resolveNbaId = onRequest(
  { cors: true, region: "us-central1", cpu: 1, memory: "512MiB" },
  async (req, res) => {
    try {
      const name = req.query.name;
      if (!name) return res.status(400).json({ error: "Missing name" });

      const url = `https://www.nba.com/search?query=${encodeURIComponent(
        name
      )}&type=player`;

      const headers = {
        "User-Agent": "Mozilla/5.0",
        Referer: "https://www.nba.com",
      };

      const result = await axios.get(url, { headers, timeout: 15000 });
      const json = typeof result.data !== "string" ? result.data : null;

      if (!json || !json.results) return res.json({ nbaId: null });

      const list = json.results;

      const exact = list.find(
        (p) =>
          p.title.toLowerCase().replace(/[^a-z ]/g, "") ===
          name.toLowerCase().replace(/[^a-z ]/g, "")
      );

      if (exact) return res.json({ nbaId: exact.id });

      const fuzzy = list.find((p) =>
        p.title.toLowerCase().includes(name.toLowerCase())
      );

      if (fuzzy) return res.json({ nbaId: fuzzy.id });

      return res.json({ nbaId: null });
    } catch (err) {
      logger.error("resolveNbaId error:", err.message);
      return res.status(500).json({ error: "NBA ID resolve failed" });
    }
  }
);



// ================================================================
// 2. exportNBAPlayers — Dump all players
// ================================================================
exports.exportNBAPlayers = onRequest(
  { cors: true, region: "us-central1", cpu: 1, memory: "512MiB" },
  async (req, res) => {
    try {
      const snap = await db.collection("nba_players").get();
      const players = snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      return res.json(players);
    } catch (err) {
      logger.error("Export error:", err.message);
      return res.status(500).json({ error: err.message });
    }
  }
);

exports.findBBRefPlayer = functions.https.onCall(async (data, context) => {
  const name = data.name;
  const query = encodeURIComponent(name);

  const url = `https://www.basketball-reference.com/search/search.fcgi?search=${query}`;

  const res = await fetch(url);
  const html = await res.text();

  const match = html.match(/\/players\/[a-z]\/[a-z0-9]+\.html/);
  if (!match) return { url: null };

  return { url: `https://www.basketball-reference.com${match[0]}` };
});

exports.scrapeBBRefStats = functions.https.onCall(async (data, ctx) => {
  const url = data.url;
  const res = await fetch(url);
  const html = await res.text();
  const $ = cheerio.load(html);

  let seasons = [];

  $("#per_game tbody tr").each((i, el) => {
    const year = $(el).find("th[data-stat='season']").text().trim();
    if (!year || year === "Career") return;

    seasons.push({
      season: year,
      team: $(el).find("td[data-stat='team_id']").text(),
      age: $(el).find("td[data-stat='age']").text(),
      games: $(el).find("td[data-stat='g']").text(),
      ppg: $(el).find("td[data-stat='pts_per_g']").text(),
      rpg: $(el).find("td[data-stat='trb_per_g']").text(),
      apg: $(el).find("td[data-stat='ast_per_g']").text(),
      spg: $(el).find("td[data-stat='stl_per_g']").text(),
      bpg: $(el).find("td[data-stat='blk_per_g']").text(),
      fgPct: $(el).find("td[data-stat='fg_pct']").text(),
      threePct: $(el).find("td[data-stat='fg3_pct']").text(),
      ftPct: $(el).find("td[data-stat='ft_pct']").text(),
      tov: $(el).find("td[data-stat='tov_per_g']").text()
    });
  });

  return { seasons };
});

exports.updatePlayerStats = functions.https.onCall(async (data, ctx) => {
  const playerId = data.playerId;
  const url = data.url;

  const stats = await exports.scrapeBBRefStats({ url }, ctx);

  await admin.firestore()
    .collection("player_stats")
    .doc(playerId)
    .set(
      {
        retiredStats: stats.seasons   // 🔥 NEW FIELD
      },
      { merge: true }
    );

  return { success: true };
});

// ================================================================
// 3. getPlayerStats — Scrape NBA.com + fetch BallDontLie seasons
// ================================================================
exports.getPlayerStats = onRequest(
  { cors: true, region: "us-central1", cpu: 1, memory: "1GiB" },
  async (req, res) => {
    try {
      const playerId = req.query.id;
      const nbaId = req.query.nbaId;

      if (!playerId || !nbaId)
        return res.status(400).json({ error: "Missing id or nbaId" });

      const headers = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json, text/plain, */*",
        "x-nba-stats-origin": "stats",
        "x-nba-stats-token": "true",
      };

      const seasonUrl = `https://www.nba.com/stats/player/${nbaId}/traditional`;
      const seasonRes = await axios.get(seasonUrl, { headers });
      const seasonText = seasonRes.data.toString();

      function extract(label) {
        const r = new RegExp(`"${label}":(.*?),"`);
        const m = seasonText.match(r);
        return m ? parseFloat(m[1]) : null;
      }

      const scraped = {
        ppg: extract("PTS"),
        rpg: extract("REB"),
        apg: extract("AST"),
        spg: extract("STL"),
        bpg: extract("BLK"),
        tov: extract("TOV"),
        fgPct: extract("FG_PCT"),
        threePct: extract("FG3_PCT"),
        ftPct: extract("FT_PCT"),
        season: getCurrentSeason(),
      };

      const projections = projectNextSeason(scraped);

      // BallDontLie historical seasons
      async function fetchBDLSeasons(bdlId) {
        const currentYear = new Date().getFullYear();
        const startSeason = currentYear - 1;

        const auth = { Authorization: "1615ce88-0491-4081-8c7f-3bff27171261" };
        let seasons = {};

        for (let year = startSeason - 3; year < startSeason; year++) {
          try {
            const url = `https://api.balldontlie.io/v1/season_averages?season=${year}&player_ids[]=${bdlId}`;
            const r = await axios.get(url, { headers: auth });
            const d = r.data?.data?.[0];
            if (!d) continue;

            seasons[`${year}-${year + 1}`] = {
              ppg: d.pts || 0,
              rpg: d.reb || 0,
              apg: d.ast || 0,
              spg: d.stl || 0,
              bpg: d.blk || 0,
              tov: d.turnover || 0,
              fgPct: d.fg_pct || 0,
              threePct: d.fg3_pct || 0,
              ftPct: d.ft_pct || 0,
            };
          } catch (e) {
            logger.warn("BDL error", e.message);
          }
        }
        return seasons;
      }

      const playerDoc = await db.collection("nba_players").doc(playerId).get();
      const bdlId = playerDoc.data()?.bdlId || nbaId;

      const bdlSeasons = await fetchBDLSeasons(bdlId);

      const allSeasonAverages = {
        ...bdlSeasons,
        [scraped.season]: scraped,
      };

      // ----------------------
// ESPN Integration
// ----------------------
const espnId = playerDoc.data()?.espnId;

let espnStats = null;

if (espnId) {
  try {
    const espnUrl = `https://getespnstats-XXXXX.a.run.app?espnId=${espnId}`;
    const result = await axios.get(espnUrl);
    espnStats = result.data;
  } catch (e) {
    logger.warn("ESPN fetch failed", e.message);
  }
}

const merged = {
  ...scraped,        // NBA.com
  ...espnStats,      // ESPN stats override if present
  season: scraped.season,
};

      await db.collection("player_stats").doc(playerId).set(
        {
          playerId,
          nbaId,
          lastUpdated: new Date().toISOString(),
          seasonAverages: scraped,
          projections,
          allSeasonAverages,
        },
        { merge: true }
      );

      return res.json({
        seasonAverages: scraped,
        projections,
        allSeasonAverages,
      });
    } catch (err) {
      logger.error("getPlayerStats error:", err.message);
      return res.status(500).json({ error: "Failed to get stats" });
    }
  }
);

exports.downloadEspnPhoto = onRequest({ cors: true }, async (req, res) => {
  try {
    const espnId = req.query.espnId;
    if (!espnId) return res.status(400).json({ error: "Missing espnId" });

    const url = `https://a.espncdn.com/i/headshots/nba/players/full/${espnId}.png`;

    const response = await axios.get(url, {
      responseType: "arraybuffer",
      headers: { "User-Agent": "Mozilla/5.0" },
    });

    const bucket = admin.storage().bucket();
    const file = bucket.file(`player_photos/espn/${espnId}.png`);

    await file.save(Buffer.from(response.data), {
      metadata: { contentType: "image/png" },
      public: true,
    });

    const publicUrl = file.publicUrl();

    // Update all players with this espnId
    const snap = await db
      .collection("nba_players")
      .where("espnId", "==", espnId.toString())
      .get();

    for (const doc of snap.docs) {
      await doc.ref.update({ espnPhoto: publicUrl });
    }

    return res.json({
      success: true,
      url: publicUrl,
    });

  } catch (err) {
    logger.error("downloadEspnPhoto error:", err.message);
    return res.status(500).json({ error: "Failed to download ESPN photo" });
  }
});

exports.onEspnPlayerCreated = onDocumentCreated(
  "nba_players/{playerId}",
  async (event) => {
    const data = event.data.data();
    const espnId = data.espnId;
    if (!espnId) return null;

    try {
      const url = `https://a.espncdn.com/i/headshots/nba/players/full/${espnId}.png`;

      const response = await axios.get(url, {
        responseType: "arraybuffer",
        headers: { "User-Agent": "Mozilla/5.0" },
      });

      const bucket = admin.storage().bucket();
      const file = bucket.file(`player_photos/espn/${espnId}.png`);

      await file.save(Buffer.from(response.data), {
        metadata: { contentType: "image/png" },
        public: true,
      });

      await event.data.ref.update({
        espnPhoto: file.publicUrl(),
      });

      return true;
    } catch (err) {
      logger.error("ESPN auto-image error:", err.message);
      return null;
    }
  }
);

exports.bulkDownloadEspnPhotos = onRequest({ cors: true }, async (req, res) => {
  try {
    const snap = await db.collection("nba_players").get();

    let processed = 0;
    let failed = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const espnId = data.idESPN; 
      if (!espnId) continue;

      try {
        const url = `https://a.espncdn.com/i/headshots/nba/players/full/${espnId}.png`;

        const resp = await axios.get(url, {
          responseType: "arraybuffer",
          headers: { "User-Agent": "Mozilla/5.0" },
        });

        const file = admin.storage().bucket().file(`player_photos/espn/${espnId}.png`);
        await file.save(Buffer.from(r.data), {
          metadata: { contentType: "image/png" },
          public: true,
        });

        await doc.ref.update({ espnPhoto: file.publicUrl() });
        processed++;
      } catch (err) {
        failed.push({ id: doc.id, espnId });
      }
    }

    return res.json({ processed, failed });

  } catch (err) {
    logger.error("Bulk ESPN error:", err.message);
    return res.status(500).json({ error: "bulk failed" });
  }
});


// ================================================================
// 4. downloadPlayerPhoto — Save NBA headshot → Firebase Storage
// ================================================================
exports.downloadPlayerPhoto = onRequest(
  { cors: true, region: "us-central1", cpu: 1, memory: "512MiB" },
  async (req, res) => {
    try {
      const nbaId = req.query.nbaId;
      if (!nbaId) return res.status(400).json({ error: "Missing nbaId" });

      const url = `https://cdn.nba.com/headshots/nba/latest/260x190/${nbaId}.png`;

      const response = await axios.get(url, {
        responseType: "arraybuffer",
        headers: { "User-Agent": "Mozilla/5.0" },
      });

      const file = admin.storage().bucket().file(`player_photos/${nbaId}.png`);
      await file.save(Buffer.from(response.data), {
        metadata: { contentType: "image/png" },
        public: true,
      });

      const publicUrl = file.publicUrl();

      // update all players with this nbaId
      const snap = await db
        .collection("nba_players")
        .where("nbaId", "==", nbaId.toString())
        .get();

      for (const doc of snap.docs) {
        await doc.ref.update({ storedPhoto: publicUrl });
      }

      return res.json({ success: true, url: publicUrl });
    } catch (err) {
      logger.error("downloadPlayerPhoto error:", err.message);
      return res.status(500).json({ error: "failed to download image" });
    }
  }
);



// ================================================================
// 5. bulkDownloadAllPhotos — Update every stored photo
// ================================================================
exports.bulkDownloadAllPhotos = onRequest(
  { cors: true, region: "us-central1", cpu: 2, memory: "1GiB" },
  async (req, res) => {
    try {
      const snap = await db.collection("nba_players").get();

      let processed = 0;
      let failed = [];

      for (const doc of snap.docs) {
        const nbaId = doc.data().nbaId;
        if (!nbaId) continue;

        try {
          const url = `https://cdn.nba.com/headshots/nba/latest/260x190/${nbaId}.png`;

          const r = await axios.get(url, {
            responseType: "arraybuffer",
            headers: { "User-Agent": "Mozilla/5.0" },
          });

          const file = admin
            .storage()
            .bucket()
            .file(`player_photos/${nbaId}.png`);
          await file.save(Buffer.from(r.data), {
            metadata: { contentType: "image/png" },
            public: true,
          });

          await doc.ref.update({ storedPhoto: file.publicUrl() });

          processed++;
        } catch (e) {
          failed.push({ id: doc.id, nbaId });
        }
      }

      return res.json({ processed, failed });
    } catch (err) {
      logger.error("Bulk error:", err.message);
      return res.status(500).json({ error: "bulk failed" });
    }
  }
);

exports.refreshEspnPhoto = onRequest({ cors: true }, async (req, res) => {
  try {
    const playerId = req.query.playerId;
    if (!playerId) return res.status(400).json({ error: "Missing playerId" });

    const snap = await db.collection("nba_players").doc(playerId).get();
    if (!snap.exists) return res.status(404).json({ error: "Player not found" });

    const data = snap.data();
    const espnId = data.idESPN;
    if (!espnId) return res.status(400).json({ error: "No idESPN on document" });

    const url = `https://a.espncdn.com/i/headshots/nba/players/full/${espnId}.png`;

    const resp = await axios.get(url, {
      responseType: "arraybuffer",
      headers: { "User-Agent": "Mozilla/5.0" },
    });

    const file = admin.storage().bucket().file(`espn_photos/${espnId}.png`);
    await file.save(Buffer.from(resp.data), {
      metadata: { contentType: "image/png" },
      public: true,
    });

    const publicUrl = file.publicUrl();
    await snap.ref.update({ espnPhoto: publicUrl });

    return res.json({ success: true, url: publicUrl });
  } catch (err) {
    logger.error("refreshEspnPhoto error:", err.message);
    return res.status(500).json({ error: "refresh failed" });
  }
});


// ================================================================
// 6. onPlayerCreated — Automatically download photo
// ================================================================
exports.onPlayerCreated = onDocumentCreated(
  {
    region: "us-central1",
    cpu: 1,
    memory: "512MiB",
  },
  "nba_players/{playerId}",
  async (event) => {
    const data = event.data.data();
    const nbaId = data.nbaId;
    if (!nbaId) return null;

    try {
      const url = `https://cdn.nba.com/headshots/nba/latest/260x190/${nbaId}.png`;

      const r = await axios.get(url, {
        responseType: "arraybuffer",
        headers: { "User-Agent": "Mozilla/5.0" },
      });

      const file = admin.storage().bucket().file(`player_photos/${nbaId}.png`);
      await file.save(Buffer.from(r.data), {
        metadata: { contentType: "image/png" },
        public: true,
      });

      await event.data.ref.update({ storedPhoto: file.publicUrl() });

      return true;
    } catch (err) {
      logger.error("Auto image error:", err.message);
      return null;
    }
  }
);



// ================================================================
// 7. refreshPlayerPhotosNightly — Every night @ 3AM EST
// ================================================================
exports.refreshPlayerPhotosNightly = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "America/New_York",
    region: "us-central1",
    cpu: 1,
    memory: "1GiB",
  },
  async () => {
    const snap = await db.collection("nba_players").get();

    for (const doc of snap.docs) {
      const nbaId = doc.data().nbaId;
      if (!nbaId) continue;

      try {
        const url = `https://cdn.nba.com/headshots/nba/latest/260x190/${nbaId}.png`;

        const r = await axios.get(url, {
          responseType: "arraybuffer",
          headers: { "User-Agent": "Mozilla/5.0" },
        });

        const file = admin.storage().bucket().file(`player_photos/${nbaId}.png`);
        await file.save(Buffer.from(r.data), {
          metadata: { contentType: "image/png" },
          public: true,
        });

        await doc.ref.update({ storedPhoto: file.publicUrl() });
      } catch (err) {
        logger.error("Nightly refresh error:", nbaId, err.message);
      }
    }

    return true;
  }
);
const resolveEspnId = exports.resolveEspnId = onRequest({ cors: true }, async (req, res) => {
  try {
    const name = req.query.name;
    if (!name) return res.status(400).json({ error: "Missing name" });

    const searchUrl = `https://site.web.api.espn.com/apis/search/v2?q=${encodeURIComponent(name)}&limit=5`;

    const response = await axios.get(searchUrl, { headers: { "User-Agent": "Mozilla/5.0" } });
    const results = response.data.results;

    if (!results || results.length === 0)
      return res.json({ espnId: null });

    for (const r of results) {
      if (r.type === "player" && r.league === "nba") {
        const href = r.href; 
        const m = href.match(/\/id\/(\d+)\//);
        if (m) return res.json({ espnId: m[1] });
      }
    }

    return res.json({ espnId: null });
  } catch (err) {
    logger.error("resolveEspnId error:", err.message);
    res.status(500).json({ error: "ESPN resolve failed" });
  }
});

exports.getEspnStats = onRequest({ cors: true }, async (req, res) => {
  try {
    const espnId = req.query.espnId;
    if (!espnId) return res.status(400).json({ error: "Missing espnId" });

    const url = `https://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/athletes/${espnId}/statistics`;

    const response = await axios.get(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    const data = response.data;

    if (!data || !data.splits) {
      return res.json({ stats: null });
    }

    let latest = data.splits.categories.find(cat => cat.name === "perGame");

    const stats = {};
    latest.stats.forEach(s => {
      stats[s.name] = s.value;
    });

    return res.json(stats);

  } catch (err) {
    logger.error("getEspnStats error:", err.message);
    res.status(500).json({ error: "Failed to fetch ESPN stats" });
  }
});

exports.autoMatchESPNIds = onRequest({ cors: true, timeoutSeconds: 540 }, async (req, res) => {
  try {
    // 1. Fetch master list of all athlete URLs
    const masterUrl =
      "https://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/athletes?limit=5000";
    const masterRes = await axios.get(masterUrl);
    const items = masterRes.data.items || [];

    if (!items.length) {
      return res.status(500).json({ error: "ESPN returned no athletes." });
    }

    // Utility: normalize names
    function cleanName(name) {
      return name
        .toLowerCase()
        .replace(/jr\.?|sr\.?|iii|ii/gi, "")
        .replace(/[^a-z ]/g, "")
        .trim();
    }

    // 2. Build ESPN name → id index
    const espnIndex = {};

    for (const item of items) {
      try {
        const athleteRes = await axios.get(item.$ref);
        const data = athleteRes.data;

        if (!data.fullName || !data.id) continue;

        const cleaned = cleanName(data.fullName);
        espnIndex[cleaned] = data.id;

      } catch (err) {
        console.warn("Failed ESPN detail fetch:", err.message);
      }
    }

    // 3. Load Firestore players
    const snap = await db.collection("nba_players").get();

    let updated = 0;
    let failed = [];

    for (const doc of snap.docs) {
      const d = doc.data();
      const name = d.name || d.strPlayer || null;

      if (!name) continue;

      const cleaned = cleanName(name);

      // Skip if already set
      if (d.idESPN && d.idESPN !== null) continue;

      const match = espnIndex[cleaned];

      if (!match) {
        failed.push({ playerId: doc.id, name });
        continue;
      }

      await doc.ref.update({ idESPN: match });
      updated++;
    }

    return res.json({
      status: "OK",
      updated,
      failedCount: failed.length,
      failed
    });

  } catch (err) {
    console.error("autoMatchESPNIds error:", err);
    return res.status(500).json({ error: err.message });
  }
});

exports.downloadESPNPhoto = onRequest({ cors: true }, async (req, res) => {
  try {
    const espnId = req.query.espnId;
    const playerId = req.query.playerId;

    if (!espnId || !playerId) {
      return res.status(400).json({ error: "Missing espnId or playerId" });
    }

    const photoUrl =
      `https://a.espncdn.com/combiner/i?img=/i/headshots/nba/players/full/${espnId}.png`;

    console.log("Fetching ESPN image:", photoUrl);

    const response = await axios.get(photoUrl, {
      responseType: "arraybuffer",
      headers: { "User-Agent": "Mozilla/5.0" }
    });

    const bucket = admin.storage().bucket();
    const file = bucket.file(`player_photos_espn/${espnId}.png`);

    await file.save(Buffer.from(response.data), {
      metadata: { contentType: "image/png" },
      public: true,
      resumable: false
    });

    const publicUrl = file.publicUrl();

    await db.collection("nba_players").doc(playerId).set(
      { espnPhoto: publicUrl },
      { merge: true }
    );

    return res.json({ success: true, url: publicUrl });

  } catch (err) {
    console.error("downloadESPNPhoto ERROR:", err);
    return res.status(500).json({ error: "Failed to save image to Firebase Storage" });
  }
});

