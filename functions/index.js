

const functions = require("firebase-functions");
const axios = require("axios");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const SPORTDB_KEY = "657478";

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
