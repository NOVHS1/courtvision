const admin = require("firebase-admin");
const fs = require("fs");
const axios = require("axios");

// -------------------------------------------
// 1. Load Firebase service account
// -------------------------------------------
const serviceAccount = require("./functions-serviceAccount.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// -------------------------------------------
// 2. NBA API URL + required headers
// -------------------------------------------
const NBA_URL =
  "https://stats.nba.com/stats/commonallplayers?LeagueID=00&Season=2023-24";

const headers = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36",
  "Accept": "application/json, text/plain, */*",
  "Referer": "https://www.nba.com",
  "Origin": "https://www.nba.com",
  "Connection": "keep-alive",
};

// -------------------------------------------
// 3. Normalize names
// -------------------------------------------
function normalize(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z ]/g, "")
    .trim();
}

// -------------------------------------------
// 4. Main upload function
// -------------------------------------------
async function uploadNbaIds() {
  console.log("Downloading NBA official player list...");

  const response = await axios.get(NBA_URL, { headers });
  const data = response.data;

  const results = data.resultSets[0];
  const headersList = results.headers;
  const rows = results.rowSet;

  const PERSON_ID_INDEX = headersList.indexOf("PERSON_ID");
  const PLAYER_NAME_INDEX = headersList.indexOf("DISPLAY_FIRST_LAST");

  const nbaPlayers = rows.map((row) => {
    return {
      nbaId: String(row[PERSON_ID_INDEX]),
      name: row[PLAYER_NAME_INDEX],
      norm: normalize(row[PLAYER_NAME_INDEX]),
    };
  });

  console.log(`NBA API returned ${nbaPlayers.length} players`);

  // -------------------------------------------
  // Fetch local Firestore players
  // -------------------------------------------
  const snap = await db.collection("nba_players").get();
  const localPlayers = snap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    norm: normalize(doc.data().strPlayer),
  }));

  console.log(`Firestore has ${localPlayers.length} players`);

  let matched = 0;
  const batch = db.batch();

  localPlayers.forEach((local) => {
    const found = nbaPlayers.find((nba) => nba.norm === local.norm);

    if (found) {
      matched++;
      console.log(`✔ MATCH: ${local.strPlayer} → ${found.nbaId}`);

      const ref = db.collection("nba_players").doc(local.id);
      batch.update(ref, { nbaId: found.nbaId });
    } else {
      console.log(`NO MATCH: ${local.strPlayer}`);
    }
  });

  await batch.commit();

  console.log(`\n🎉 DONE: ${matched} players matched and updated.`);
  process.exit(0);
}

// Run the script
uploadNbaIds().catch((err) => {
  console.error("ERROR:", err);
  process.exit(1);
});
