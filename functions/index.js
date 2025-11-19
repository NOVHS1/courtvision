const functions = require("firebase-functions");
const axios = require("axios");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const ENABLE_SPORTSRADAR = false;

// -------------------------------
// Detect Current NBA Season
// -------------------------------
function getCurrentSeason() {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth() + 1;
  const start = m >= 10 ? y : y - 1;
  const end = start + 1;
  return `${start}-${end.toString().slice(-2)}`;
}

// -------------------------------------------------------
// Resolve NBA.com “nbaId” from player name
// -------------------------------------------------------
exports.resolveNbaId = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  try {
    const name = req.query.name;
    if (!name) return res.status(400).json({ error: "Missing 'name'" });

    console.log("Resolving NBA ID for:", name);

    const url = `https://www.nba.com/search?query=${encodeURIComponent(
      name
    )}&type=player`;

    const headers = {
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      Referer: "https://www.nba.com",
    };

    const result = await axios.get(url, { headers, timeout: 15000 });

    let json = null;
    if (typeof result.data !== "string") json = result.data;

    if (!json || !json.results) {
      console.log("No JSON results (likely HTML), returning null");
      return res.status(200).json({ nbaId: null });
    }

    const list = json.results;

    // Exact match
    const exact = list.find(
      (p) =>
        p.title.toLowerCase().replace(/[^a-z ]/g, "") ===
        name.toLowerCase().replace(/[^a-z ]/g, "")
    );

    if (exact) return res.status(200).json({ nbaId: exact.id });

    // Fuzzy match
    const fuzzy = list.find((p) =>
      p.title.toLowerCase().includes(name.toLowerCase())
    );

    if (fuzzy) return res.status(200).json({ nbaId: fuzzy.id });

    return res.status(200).json({ nbaId: null });
  } catch (e) {
    console.error("resolveNbaId error:", e.message);
    return res.status(500).json({ error: "NBA ID resolve failed" });
  }
});

// -------------------------------------------------------
// Export All nba_players Collection
// -------------------------------------------------------
exports.exportNBAPlayers = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  try {
    const snap = await db.collection("nba_players").get();

    const players = snap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return res.status(200).json(players);
  } catch (err) {
    console.error("Export error:", err);
    return res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------
// Fetch Player Stats via NBA.com Scrape
// -------------------------------------------------------
exports.getPlayerStats = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  try {
    const playerId = req.query.id;
    const nbaId = req.query.nbaId;

    if (!playerId || !nbaId) {
      return res
        .status(400)
        .json({ error: "Missing 'id' or 'nbaId' parameter" });
    }

    const season = getCurrentSeason();
    console.log(`Fetching stats for nbaId = ${nbaId} | Season = ${season}`);

    const headers = {
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      Referer: "https://www.nba.com",
    };

    // --------- GAME LOG SCRAPE ----------
    const gameLogUrl = `https://www.nba.com/stats/player/${nbaId}/gamelogs`;
    const gameLogRes = await axios.get(gameLogUrl, { headers });
    const gameLogText = gameLogRes.data.toString();

    const gameLogs = [];
    const logMatch = gameLogText.match(/"gamelog":(\[.*?\])/s);

    if (logMatch) {
      const parsed = JSON.parse(logMatch[1]);
      parsed.slice(0, 5).forEach((g) => {
        gameLogs.push({
          date: g["GAME_DATE"],
          opponent: g["MATCHUP"],
          result: g["WL"],
          pts: g["PTS"],
          reb: g["REB"],
          ast: g["AST"],
          stl: g["STL"],
          blk: g["BLK"],
          fgPct: g["FG_PCT"],
          threePct: g["FG3_PCT"],
        });
      });
    }

    // --------- SEASON AVERAGES ----------
    const seasonUrl = `https://www.nba.com/stats/player/${nbaId}/traditional`;
    const seasonRes = await axios.get(seasonUrl, { headers });
    const seasonText = seasonRes.data.toString();

    function extract(label) {
      const r = new RegExp(`"${label}":(.*?),"`);
      const m = seasonText.match(r);
      return m ? parseFloat(m[1]) : null;
    }

    const seasonAverages = {
      ppg: extract("PTS"),
      rpg: extract("REB"),
      apg: extract("AST"),
      spg: extract("STL"),
      bpg: extract("BLK"),
      tov: extract("TOV"),
      fgPct: extract("FG_PCT"),
      threePct: extract("FG3_PCT"),
      ftPct: extract("FT_PCT"),
    };

    // --------- SAVE ---------
    await db
      .collection("player_stats")
      .doc(playerId)
      .set(
        {
          playerId,
          nbaId,
          lastUpdated: new Date().toISOString(),
          seasonAverages,
          gameLogs,
        },
        { merge: true }
      );

    return res.status(200).json({
      seasonAverages,
      gameLogs,
    });
  } catch (error) {
    console.error("getPlayerStats Error:", error.message);
    return res.status(500).json({ error: "Failed to get stats" });
  }
});

// -------------------------------------------------------
// Assign nbaId to all players in nba_players
// -------------------------------------------------------
exports.assignNbaIds = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  try {
    console.log("Starting NBA ID assignment for all players...");

    const snap = await db.collection("nba_players").get();
    const players = snap.docs;

    console.log(`Found ${players.length} players in Firestore.`);

    let updatedCount = 0;

    // Loop through each player
    for (const doc of players) {
      const data = doc.data();
      const name = data.strPlayer;

      if (!name) continue;

      const resolveUrl =
        `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/resolveNbaId?name=` +
        encodeURIComponent(name);

      try {
        const resId = await axios.get(resolveUrl, { timeout: 15000 });
        const nbaId = resId.data.nbaId;

        if (nbaId) {
          await doc.ref.update({ nbaId });
          updatedCount++;
          console.log(`✔ Updated ${name} → nbaId: ${nbaId}`);
        } else {
          console.log(`✖ No NBA ID found for ${name}`);
        }
      } catch (err) {
        console.log(`Error resolving ${name}:`, err.message);
      }

      // Rate-limit to avoid hammering NBA.com
      await new Promise((r) => setTimeout(r, 300));
    }

    return res.status(200).json({
      message: "NBA ID assignment finished",
      updated: updatedCount
    });

  } catch (e) {
    console.error("assignNbaIds ERROR:", e);
    return res.status(500).json({ error: e.message });
  }
});
