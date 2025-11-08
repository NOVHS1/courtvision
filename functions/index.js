
const functions = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

const SPORTRADAR_API_KEY = "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k";

// Helper: team UUID map with timeout
async function loadTeamUUIDMap() {
  const url = `https://api.sportradar.us/nba/trial/v8/en/league/hierarchy.json?api_key=${SPORTRADAR_API_KEY}`;
  console.log(`Fetching team hierarchy from: ${url}`);
  try {
    const response = await axios.get(url, { timeout: 15000 });
    const conferences = response.data.conferences || [];
    const idMap = {};
    conferences.forEach((conf) => {
      conf.divisions.forEach((div) => {
        div.teams.forEach((team) => {
          idMap[team.reference] = team.id;
        });
      });
    });
    console.log(`Loaded ${Object.keys(idMap).length} team UUIDs`);
    return idMap;
  } catch (error) {
    console.error("Failed to load team UUIDs:", error.message);
    return {};
  }
}

// Fetch NBA Games (CORS-enabled)
exports.fetchNBAGames = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const dateParam = req.query.date;
    const now = dateParam ? new Date(dateParam) : new Date();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const day = String(now.getUTCDate()).padStart(2, "0");
    const dateString = `${year}-${month}-${day}`;

    const url = `https://api.sportradar.us/nba/trial/v8/en/games/${year}/${month}/${day}/schedule.json?api_key=${SPORTRADAR_API_KEY}`;
    console.log(`Fetching NBA schedule for ${dateString} from: ${url}`);

    const response = await axios.get(url, { timeout: 15000 });
    const games = response.data.games || [];

    if (!games.length) {
      console.log(`No games found for ${dateString}`);
      return res.status(200).json({ games: [] });
    }

    const uuidMap = await loadTeamUUIDMap().catch(() => ({}));
    const batch = db.batch();

    games.forEach((game) => {
      const homeRef = game.home?.reference;
      const awayRef = game.away?.reference;
      const docRef = db.collection("nba_games").doc(game.id.toString());
      batch.set(docRef, {
        ...game,
        fetchedDate: dateString,
        home: { ...game.home, uuid: uuidMap[homeRef] || null },
        away: { ...game.away, uuid: uuidMap[awayRef] || null },
      });
    });

    await batch.commit();
    console.log(`Saved ${games.length} games for ${dateString}`);
    return res.status(200).json({ message: "Games saved", count: games.length, games });
  } catch (error) {
    console.error("Error fetching NBA games:", error.message);
    return res.status(500).json({ error: error.message || "Unknown error" });
  }
});

// Auto-refresh every 10 minutes
exports.refreshNBAGames = onSchedule("every 10 minutes", async () => {
  console.log("Running scheduled NBA game refresh...");
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  const day = String(now.getUTCDate()).padStart(2, "0");
  const dateString = `${year}-${month}-${day}`;

  try {
    const url = `https://api.sportradar.us/nba/trial/v8/en/games/${year}/${month}/${day}/schedule.json?api_key=${SPORTRADAR_API_KEY}`;
    const response = await axios.get(url, { timeout: 15000 });
    const games = response.data.games || [];

    const batch = db.batch();
    games.forEach((game) => {
      const docRef = db.collection("nba_games").doc(game.id.toString());
      batch.set(docRef, { ...game, fetchedDate: dateString }, { merge: true });
    });

    await batch.commit();
    console.log(`Updated ${games.length} games.`);
  } catch (error) {
    console.error("Error in scheduled refresh:", error.message);
  }
});

// Search Players (Firestore)
exports.searchPlayers = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const query = (req.query.name || "").toLowerCase();
    if (!query) return res.status(400).json({ error: "Missing 'name' parameter" });

    const snapshot = await db.collectionGroup("players").get();
    const players = [];
    snapshot.forEach((doc) => {
      const player = doc.data();
      if (player.name?.toLowerCase().includes(query)) players.push(player);
    });

    console.log(`Found ${players.length} players for '${query}'`);
    res.status(200).json(players);
  } catch (error) {
    console.error("Player search failed:", error.message);
    res.status(500).json({ error: error.message });
  }
});

// Get Player Stats (SportsDB + Safe Firestore write)
exports.getPlayerStats = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const playerId = req.query.id;
    if (!playerId) return res.status(400).json({ error: "Missing 'id' parameter" });

    console.log(`Fetching player stats for ID: ${playerId}`);

    // Check Firestore cache
    const cachedDoc = await db.collection("player_profiles").doc(playerId).get();
    if (cachedDoc.exists) {
      console.log(`Returning cached stats for ${playerId}`);
      return res.status(200).json(cachedDoc.data());
    }

    // Fetch from TheSportsDB
    const url = `https://www.thesportsdb.com/api/v1/json/657478/lookupplayerstats.php?id=${playerId}`;
    console.log(`SportsDB request: ${url}`);

    const axiosResponse = await axios.get(url, { timeout: 15000 });
    const data = axiosResponse.data;

    // Validate structure
    if (!data || typeof data !== "object") {
      console.error("Invalid response from SportsDB:", data);
      return res.status(500).json({ error: "Invalid response from SportsDB" });
    }

    const statsArray = data.playerstats;
    if (!Array.isArray(statsArray) || statsArray.length === 0) {
      console.warn(`No stats found for player ${playerId}`);
      return res.status(200).json({ message: "No stats available" });
    }

    const playerStats = statsArray[0];
    console.log(`Stats fetched for ${playerId}: ${Object.keys(playerStats).length} fields`);

    // Safe Firestore write
    await db
      .collection("player_profiles")
      .doc(playerId)
      .set({ playerId, ...playerStats }, { merge: true });

    console.log(`Player stats saved in Firestore: ${playerId}`);
    return res.status(200).json(playerStats);

  } catch (error) {
    console.error("Error fetching player stats:", error);
    res.status(500).json({ error: error.message || "Unknown error" });
  }
});
