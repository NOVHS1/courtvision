const functions = require("firebase-functions");
const axios = require("axios");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const SPORTRADAR_API_KEY = "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k";

// Fetch today's NBA games
exports.fetchNBAGames = functions.https.onRequest(async (req, res) => {
  try {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const day = String(now.getDate()).padStart(2, "0");

    const url =
      "https://api.sportradar.us/nba/trial/v8/en/games/" +
      `${year}/${month}/${day}/schedule.json?api_key=${SPORTRADAR_API_KEY}`;

    const response = await axios.get(url);
    const games = response.data.games || [];
    const batch = db.batch();

    games.forEach((game) => {
      const docRef = db.collection("nba_games").doc(game.id.toString());
      batch.set(docRef, game);
    });

    await batch.commit();
    res.status(200).send({
      message: "Games saved to Firestore",
      count: games.length,
    });
  } catch (error) {
    console.error("Error fetching NBA games:", error.message);
    res.status(500).send({ error: error.message });
  }
});

// Shared function: fetch and update rosters
async function updateRosters() {
  const apiKey = SPORTRADAR_API_KEY;

  const leagueUrl =
    "https://api.sportradar.us/nba/trial/v8/en/league/" +
    `hierarchy.json?api_key=${apiKey}`;
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

  console.log(`Found ${teamIds.length} total teams`);

  for (const teamId of teamIds) {
    try {
      const teamUrl =
        "https://api.sportradar.us/nba/trial/v8/en/teams/" +
        `${teamId}/profile.json?api_key=${apiKey}`;
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
          points_per_game:
            player.average ? player.average.points || 0 : 0,
          assists_per_game:
            player.average ? player.average.assists || 0 : 0,
          rebounds_per_game:
            player.average ? player.average.rebounds || 0 : 0,
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

// 1️⃣ Scheduled daily update (every 24 hours)
exports.updateTeamRosters = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    console.log("Running daily roster update...");
    await updateRosters();
    return null;
  });

// 2️⃣ Manual HTTPS trigger (for testing or instant refresh)
exports.manualUpdateRosters = functions.https.onRequest(async (req, res) => {
  try {
    console.log("Manual roster update started...");
    const result = await updateRosters();
    res.status(200).send({message: "Manual roster update complete", result});
  } catch (error) {
    console.error("Manual roster update failed:", error.message);
    res.status(500).send({ error: error.message });
  }
});
