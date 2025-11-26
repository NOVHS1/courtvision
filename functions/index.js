const functions = require("firebase-functions");
const axios = require("axios");
const admin = require("firebase-admin");
const cheerio = require("cheerio");

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

// -------------------------------
// Predict Next Season
// -------------------------------
function projectNextSeason(current) {
  if (!current) return null;

  let projected = {};
  Object.keys(current).forEach(k => {
    if (typeof current[k] === "number") {
      projected[k] = parseFloat((current[k] * 1.01).toFixed(3)); // small boost
    } else {
      projected[k] = current[k];
    }
  });

  ["fgPct", "threePct", "ftPct"].forEach(k => {
    if (projected[k] > 0.70) projected[k] = 0.70;
    if (projected[k] < 0.20) projected[k] = 0.20;
  });

  return projected;
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
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64;)",
      Referer: "https://www.nba.com",
    };

    const result = await axios.get(url, { headers, timeout: 15000 });

    let json = null;
    if (typeof result.data !== "string") json = result.data;

    if (!json || !json.results) {
      console.log("No JSON results, returning null");
      return res.status(200).json({ nbaId: null });
    }

    const list = json.results;

    const exact = list.find(
      (p) =>
        p.title.toLowerCase().replace(/[^a-z ]/g, "") ===
        name.toLowerCase().replace(/[^a-z ]/g, "")
    );

    if (exact) return res.status(200).json({ nbaId: exact.id });

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
// Fetch Player Stats via NBA.com (CURRENT SEASON ONLY)
// -------------------------------------------------------
exports.getPlayerStats = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  try {
    const playerId = req.query.id;
    const nbaId = req.query.nbaId;
    if (!playerId || !nbaId)
      return res.status(400).json({ error: "Missing 'id' or 'nbaId'" });

    console.log(`Fetching stats for nbaId = ${nbaId}`);

    const headers = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
      "Accept": "application/json, text/plain, */*",
      "x-nba-stats-origin": "stats",
      "x-nba-stats-token": "true"
    };

    // --------- CURRENT SEASON ONLY ----------
    const seasonUrl = `https://www.nba.com/stats/player/${nbaId}/traditional`;
    const seasonRes = await axios.get(seasonUrl, { headers });
    const seasonText = seasonRes.data.toString();

    function extract(label) {
      const r = new RegExp(`"${label}":(.*?),"`);
      const m = seasonText.match(r);
      return m ? parseFloat(m[1]) : null;
    }

    const current = {
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

    // --------- PROJECT NEXT SEASON ----------
    const projectedNextSeason = projectNextSeason(current);

    // --------- SAVE ---------
    await db.collection("player_stats").doc(playerId).set(
      {
        playerId,
        nbaId,
        lastUpdated: new Date().toISOString(),
        seasonAverages: current,
        projections: projectedNextSeason,
      },
      { merge: true }
    );

    return res.status(200).json({
      seasonAverages: current,
      projections: projectedNextSeason,
    });
  } catch (error) {
    console.error("getPlayerStats Error:", error);
    return res.status(500).json({ error: "Failed to get stats" });
  }
});
