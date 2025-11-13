const functions = require("firebase-functions");
const axios = require("axios");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const ENABLE_SPORTSRADAR = false; 
// Set to true to activate Sportradar

const SPORTRADAR_API_KEY = functions.config().sportradar?.key || "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k";
const SPORTDB_KEY = "657478";

exports.fetchNBAGames = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    if (!ENABLE_SPORTSRADAR) {
      console.log("Sportradar API is disabled. Returning placeholder response.");
      return res.status(200).json({
        disabled: true,
        message: "Sportradar disabled. No external game data fetched."
      });
    }

    const dateParam = req.query.date;
    const now = dateParam ? new Date(dateParam) : new Date();

    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const day = String(now.getUTCDate()).padStart(2, "0");

    const url = `https://api.sportradar.us/nba/trial/v8/en/games/${year}/${month}/${day}/schedule.json?api_key=${SPORTRADAR_API_KEY}`;
    console.log(`Fetching games from Sportradar: ${url}`);

    const response = await axios.get(url, { timeout: 15000 });
    const games = response.data.games || [];

    if (!games.length) {
      console.log("No games returned from Sportradar for this date.");
      return res.status(200).json({ games: [] });
    }

    // Save games into Firestore
    const batch = db.batch();
    games.forEach((game) => {
      const ref = db.collection("nba_games").doc(game.id.toString());
      batch.set(ref, { ...game, fetchedDate: `${year}-${month}-${day}` });
    });

    await batch.commit();

    return res.status(200).json({
      message: "Games saved",
      count: games.length,
      games
    });

  } catch (error) {
    console.error("Error fetching NBA games:", error.message);
    return res.status(500).json({
      error: error.message || "Unknown error"
    });
  }
});


exports.getPlayerStats = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const playerId = req.query.id;
    if (!playerId)
      return res.status(400).json({ error: "Missing 'id' parameter" });

    console.log(`Fetching recent events for player ${playerId}...`);

    const recentUrl = `https://www.thesportsdb.com/api/v1/json/${SPORTDB_KEY}/eventslast.php?id=${playerId}`;
    const recentRes = await axios.get(recentUrl, { timeout: 15000 });
    const recentData = recentRes.data;

    if (!recentData?.results?.length) {
      console.warn(`No recent events found for player ${playerId}`);
      return res.status(200).json({ message: "No stats available" });
    }

    const events = recentData.results.slice(0, 5);
    const stats = [];

    console.log(`Found ${events.length} recent games, fetching stats...`);

    for (const event of events) {
      const eventId = event.idEvent;
      const statsUrl = `https://www.thesportsdb.com/api/v1/json/${SPORTDB_KEY}/lookupeventstats.php?id=${eventId}`;

      try {
        const statsRes = await axios.get(statsUrl, { timeout: 15000 });
        const statData = statsRes.data;

        if (statData?.eventstats?.length) {
          const playerStats = statData.eventstats.find(
            (s) => s.idPlayer === playerId
          );
          if (playerStats) {
            stats.push({
              dateEvent: event.dateEvent,
              strEvent: event.strEvent,
              strHomeTeam: event.strHomeTeam,
              strAwayTeam: event.strAwayTeam,
              intPoints: playerStats.intPoints ?? null,
              intAssists: playerStats.intAssists ?? null,
              intRebounds: playerStats.intRebounds ?? null,
              intBlocks: playerStats.intBlocks ?? null,
              intSteals: playerStats.intSteals ?? null,
              intMinutes: playerStats.intMinutes ?? null,
            });
          }
        }
      } catch (err) {
        console.warn(`Failed to fetch stats for event ${eventId}:`, err.message);
      }
    }

    if (stats.length === 0) {
      console.warn(`No detailed stats found for ${playerId}`);
      return res.status(200).json({ message: "No detailed stats found" });
    }

    console.log(`Fetched ${stats.length} stat lines for ${playerId}`);

    await db.collection("player_stats").doc(playerId).set(
      { playerId, updated: new Date().toISOString(), stats },
      { merge: true }
    );

    return res.status(200).json({ stats });
  } catch (error) {
    console.error("Error fetching player stats:", error.message);
    return res.status(500).json({ error: error.message || "Unknown error" });
  }
});
