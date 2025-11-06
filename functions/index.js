const functions = require("firebase-functions");
const axios = require("axios");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const SPORTRADAR_API_KEY = "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k";

//Helper to get team UUIDs (used for linking rosters)
async function loadTeamUUIDMap() {
  const url = `https://api.sportradar.us/nba/trial/v8/en/league/hierarchy.json?api_key=${SPORTRADAR_API_KEY}`;
  const response = await axios.get(url);
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
}

//Fetch and save daily NBA games
exports.fetchNBAGames = functions.https.onRequest(async (req, res) => {
  try {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const day = String(now.getUTCDate()).padStart(2, "0");

    const url = `https://api.sportradar.us/nba/trial/v8/en/games/${year}/${month}/${day}/schedule.json?api_key=${SPORTRADAR_API_KEY}`;
    console.log(`Fetching NBA schedule: ${url}`);

    const response = await axios.get(url);
    const games = response.data.games || [];

    if (games.length === 0) {
      console.log("ℹ No games found for today");
      return res.status(200).send({ message: "No games found today." });
    }

    const uuidMap = await loadTeamUUIDMap();
    const batch = db.batch();

    games.forEach((game) => {
      const homeNBA = game.home?.reference;
      const awayNBA = game.away?.reference;

      const docRef = db.collection("nba_games").doc(game.id.toString());
      batch.set(docRef, {
        ...game,
        home: { ...game.home, uuid: uuidMap[homeNBA] || null },
        away: { ...game.away, uuid: uuidMap[awayNBA] || null },
      });
    });

    await batch.commit();
    console.log(`Saved ${games.length} games with UUIDs`);
    res.status(200).send({ message: "Games saved to Firestore", count: games.length });
  } catch (error) {
    console.error("Error fetching NBA games:", error.message);
    res.status(500).send({ error: error.message });
  }
});

//Scheduled auto-refresh every 10 minutes
exports.refreshNBAGames = functions.pubsub
  .schedule("every 10 minutes")
  .onRun(async () => {
    console.log("Running periodic NBA game refresh...");
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const day = String(now.getUTCDate()).padStart(2, "0");

    const url = `https://api.sportradar.us/nba/trial/v8/en/games/${year}/${month}/${day}/schedule.json?api_key=${SPORTRADAR_API_KEY}`;
    const response = await axios.get(url);
    const games = response.data.games || [];

    const batch = db.batch();
    games.forEach((game) => {
      const docRef = db.collection("nba_games").doc(game.id.toString());
      batch.set(docRef, game, { merge: true });
    });

    await batch.commit();
    console.log(`Updated ${games.length} games.`);
    return null;
  });

//Update team rosters (runs daily)
async function updateRosters() {
  const leagueUrl = `https://api.sportradar.us/nba/trial/v8/en/league/hierarchy.json?api_key=${SPORTRADAR_API_KEY}`;
  const leagueResponse = await axios.get(leagueUrl);
  const conferences = leagueResponse.data.conferences || [];
  const teamIds = [];

  conferences.forEach((conf) => {
    conf.divisions.forEach((div) => {
      div.teams.forEach((team) => {
        teamIds.push(team.id);
      });
    });
  });

  console.log(`Found ${teamIds.length} teams total`);

  for (const teamId of teamIds) {
    try {
      const teamUrl = `https://api.sportradar.us/nba/trial/v8/en/teams/${teamId}/profile.json?api_key=${SPORTRADAR_API_KEY}`;
      const response = await axios.get(teamUrl);
      const teamData = response.data;
      const players = teamData.players || [];

      const teamRef = db.collection("team_rosters").doc(teamId);
      const batch = db.batch();

      players.forEach((player) => {
        const playerRef = teamRef.collection("players").doc(player.id);
        batch.set(playerRef, {
          id: player.id,
          name: player.full_name,
          position: player.primary_position,
          points_per_game: player.average?.points || 0,
          assists_per_game: player.average?.assists || 0,
          rebounds_per_game: player.average?.rebounds || 0,
        });
      });

      await batch.commit();
      console.log(`Updated roster for ${teamData.name}`);
    } catch (err) {
      console.error(`Error fetching roster for ${teamId}:`, err.message);
    }
  }

  return { success: true };
}

// Daily scheduled roster refresh
exports.updateTeamRosters = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    console.log("Running daily roster update...");
    await updateRosters();
    return null;
  });

exports.manualUpdateRosters = functions.https.onRequest(async (req, res) => {
  try {
    console.log("Manual roster update started...");
    const result = await updateRosters();
    res.status(200).send({
      message: "Manual roster update complete",
      result,
    });
  } catch (error) {
    console.error("Manual roster update failed:", error.message);
    res.status(500).send({ error: error.message });
  }
});

exports.searchPlayers = functions.https.onRequest(async (req, res) => {
  try {
    const query = (req.query.name || "").toLowerCase();
    if (!query) {
      return res.status(400).send({ error: "Missing 'name' parameter" });
    }

    const playersSnapshot = await db.collectionGroup("players").get();
    const players = [];

    playersSnapshot.forEach((doc) => {
      const player = doc.data();
      if (player.name.toLowerCase().includes(query)) {
        players.push(player);
      }
    });

    console.log(`Found ${players.length} players for search: "${query}"`);
    res.status(200).send(players);
  } catch (error) {
    console.error("Error searching players:", error.message);
    res.status(500).send({ error: error.message });
  }
});

exports.getPlayerStats = functions.https.onRequest(async (req, res) => {
  try {
    const playerId = req.query.id;
    if (!playerId) {
      return res.status(400).send({ error: "Missing 'id' parameter" });
    }

    // First, check Firestore cache
    const snapshot = await db
      .collectionGroup("players")
      .where("id", "==", playerId)
      .get();

    if (!snapshot.empty) {
      console.log(`Player found in Firestore: ${playerId}`);
      const playerData = snapshot.docs[0].data();
      return res.status(200).send(playerData);
    }

    // Otherwise, fetch directly from Sportradar
    const url = `https://api.sportradar.us/nba/trial/v8/en/players/${playerId}/profile.json?api_key=${SPORTRADAR_API_KEY}`;
    const response = await axios.get(url);
    const data = response.data;

    // Cache player stats
    await db.collection("player_profiles").doc(playerId).set(data);

    res.status(200).send(data);
  } catch (error) {
    console.error("Error fetching player stats:", error.message);
    res.status(500).send({ error: error.message });
  }
});
