import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // API BASE URLS
  final String sportsDbBaseUrl =
      "https://www.thesportsdb.com/api/v1/json/657478";

  // Cloud Functions
  final String fetchNBAGamesUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/fetchNBAGames";
  final String searchPlayersUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/searchPlayers";
  final String getPlayerStatsUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/getPlayerStats";

  // LOCAL SWITCH (MUST MATCH YOUR INDEX.JS)
  // This only affects the frontend behavior. The backend still enforces the switch.
  static const bool ENABLE_SPORTSRADAR = false;

  // Fetch today’s games
  Future<List<dynamic>> fetchTodayGames() async {
    if (!ENABLE_SPORTSRADAR) {
      print("Sportradar disabled — skipping fetchTodayGames()");
      return [];
    }

    final now = DateTime.now().toUtc();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final url = Uri.parse("$fetchNBAGamesUrl?date=$date");

    print("Fetching NBA schedule from Cloud Function: $url");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // If backend says Sportradar disabled
        if (data is Map && data['disabled'] == true) {
          print("Backend has Sportradar disabled — returning empty list");
          return [];
        }

        final games = data['games'] ?? [];
        print("Found ${games.length} games for $date");
        return games;
      } else {
        throw Exception("Cloud Function returned ${response.statusCode}");
      }
    } catch (e) {
      print("Error loading games: $e");
      throw Exception("Error loading games: $e");
    }
  }

  // Trigger backend refresh — disabled if Sportradar off
  Future<void> refreshNBAGames() async {
    if (!ENABLE_SPORTSRADAR) {
      print("Sportradar disabled — skipping refreshNBAGames()");
      return;
    }

    try {
      print("Triggering NBA game refresh...");
      final response = await http.get(Uri.parse(fetchNBAGamesUrl));

      if (response.statusCode == 200) {
        print("NBA games refreshed successfully");
      } else {
        throw Exception("Failed to refresh games: ${response.statusCode}");
      }
    } catch (e) {
      print("Error refreshing games: $e");
      rethrow;
    }
  }

  // Search players (SportsDB)
Future<List<dynamic>> searchNBAPlayers(String name) async {
  final uri = Uri.parse("$sportsDbBaseUrl/searchplayers.php?p=$name");
  print("Searching NBA players: $name");

  try {
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("Search failed: ${response.statusCode}");
    }

    final data = json.decode(response.body);
    final List players = data['player'] ?? [];

    // NBA TEAM WHITELIST (30 teams)
    final nbaTeams = [
      "lakers", "clippers", "warriors", "kings", "suns",
      "bucks", "bulls", "celtics", "nets", "knicks",
      "heat", "magic", "hawks", "hornets", "cavaliers",
      "pistons", "pacers", "raptors", "76ers", "wizards",
      "nuggets", "timberwolves", "thunder", "blazers", "jazz",
      "mavericks", "spurs", "rockets", "pelicans", "grizzlies",
    ];

bool isBasketballPlayer(Map<String, dynamic> p) {
  final pos = (p['strPosition'] ?? "").toLowerCase();
  final team = (p['strTeam'] ?? "").toLowerCase();
  final desc = (p['strDescriptionEN'] ?? "").toLowerCase();
  final sport = (p['strSport'] ?? "").toLowerCase();
  final league = (p['strLeague'] ?? "").toLowerCase();

  // Allowed basketball player positions
  final basketballPositions = [
    "pg", "sg", "sf", "pf", "c",
    "point guard",
    "shooting guard",
    "small forward",
    "power forward",
    "center",
  ];

  // TRUE basketball player positions
  final isPositionMatch =
      basketballPositions.any((posWord) => pos.contains(posWord));

  // Keep retired NBA players
  final isRetiredBasketball =
      team.contains("_retired basketball");

  // BLOCK coaches, managers, agents, GMs, staff
  final bannedRoles = [
    "coach",
    "assistant coach",
    "head coach",
    "general manager",
    "manager",
    "agent",
    "staff",
    "trainer",
    "analyst",
    "scout",
    "executive",
    "owner",
    "chairman",
    "president"
  ];

  final isBadRole =
      bannedRoles.any((bad) => pos.contains(bad) || desc.contains(bad));

  // BLOCK other sports completely
  final bannedSports = [
    "soccer",
    "football",
    "baseball",
    "cricket",
    "rugby",
    "tennis",
    "hockey",
    "ice hockey",
    "mma",
    "boxing",
    "golf",
    "cycling",
    "volleyball",
    "handball",
    "swimming",
    "athletics",
  ];

  final mentionsOtherSport =
      bannedSports.any((bad) => sport.contains(bad) || desc.contains(bad));

  // BLOCK EuroLeague & all non-NBA leagues
  final bannedLeagues = [
    "euro league",
    "euroleague",
    "liga acb",
    "greek basket league",
    "italian lega basket",
    "lba",
    "cba",
    "nbb",
    "pba",
    "bsleague",
    "bsl",
    "vbl",
    "tbl",
    "nbl",
    "pro a",
    "pro b",
    "bbL",
  ];

  final isNonNBALeague =
      bannedLeagues.any((bad) => league.contains(bad));

  // TEAM FILTER — block European clubs, rugby, hockey, etc.
  final bannedTeamKeywords = [
    // euro clubs
    "madrid",
    "barcelona",
    "fenerbahce",
    "anadolu",
    "olympiacos",
    "panathinaikos",
    "maccabi",
    "milano",
    "valencia",
    "cska",
    "monaco",
   
    "fc",          // soccer clubs
    "cf",
    "afc",
    "rfc",         // rugby football club
    "hc",          // hockey clubs
    "ice",         // ice hockey
    "rugby",
    "cricket",
  ];

  final isBadTeam =
      bannedTeamKeywords.any((bad) => team.contains(bad));

  // RETURN true only if:
  return (isPositionMatch || isRetiredBasketball) &&
      !mentionsOtherSport &&
      !isBadRole &&
      !isBadTeam &&
      !isNonNBALeague;
}

    final filteredPlayers = players.where((p) => isBasketballPlayer(p)).toList();

    print("Filtered ${filteredPlayers.length} NBA players out of ${players.length} results.");
    return filteredPlayers;
  } catch (e) {
    print("Error searching players: $e");
    rethrow;
  }
}

  // Fetch sportsDB player stats (via Cloud Function)
  Future<Map<String, dynamic>?> getPlayerStats(String playerId) async {
    final uri = Uri.parse("$getPlayerStatsUrl?id=$playerId");
    print("Fetching player stats for $playerId");

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map<String, dynamic> && data.containsKey('message')) {
          print("No stats available for player $playerId");
          return null;
        }
        return data;
      } else {
        print("Failed to load player stats: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching player stats: $e");
      return null;
    }
  }

  // Fetch all NBA players and store in Firestore
Future<List<dynamic>> fetchAllNBAPlayers({bool forceRefresh = false}) async {
  final List<dynamic> allPlayers = [];

  if (!forceRefresh) {
    final snapshot = await _firestore.collection('nba_players').get();
    if (snapshot.docs.isNotEmpty) {
      print("Loaded ${snapshot.docs.length} cached players from Firestore");
      return snapshot.docs.map((d) => d.data()).toList();
    }
  }

  print("Fetching all NBA teams...");
  final teamsUrl = Uri.parse("$sportsDbBaseUrl/search_all_teams.php?l=NBA");
  final teamsResponse = await http.get(teamsUrl);

  if (teamsResponse.statusCode != 200) {
    throw Exception("Failed to load NBA teams");
  }

  final teamsData = json.decode(teamsResponse.body);
  final teams = teamsData['teams'] ?? [];
  print("Found ${teams.length} NBA teams");

  for (var team in teams) {
    final teamId = team['idTeam'];
    final teamName = (team['strTeam'] ?? "").toLowerCase();

    await Future.delayed(const Duration(milliseconds: 700));
    final playersUrl =
        Uri.parse("$sportsDbBaseUrl/lookup_all_players.php?id=$teamId");

    print("Fetching players for $teamName...");
    final playersResponse = await http.get(playersUrl);

    if (playersResponse.statusCode == 200) {
      final playersData = json.decode(playersResponse.body);
      final players = playersData['player'] ?? [];

      for (var player in players) {
        // Extra safety: Only allow basketball
        if (player['strSport']?.toLowerCase() == 'basketball') {
          allPlayers.add(player);

          await _firestore
              .collection('nba_players')
              .doc(player['idPlayer'])
              .set(player, SetOptions(merge: true));
        }
      }
    } else {
      print("Error fetching players for $teamName");
    }
  }

  print("Total NBA players fetched: ${allPlayers.length}");
  return allPlayers;
}

  // Roster for a team
Future<List<dynamic>> fetchTeamRoster(String teamId) async {
  final url = Uri.parse("$sportsDbBaseUrl/lookup_all_players.php?id=$teamId");
  print("Fetching roster for team ID: $teamId");

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final players = data['player'] ?? [];

      return players
          .where((p) =>
              p['strSport']?.toLowerCase() == 'basketball')
          .toList();
    } else {
      throw Exception("Failed to fetch roster: ${response.statusCode}");
    }
  } catch (e) {
    print("Error loading roster: $e");
    throw Exception("Error loading roster: $e");
  }
}

  // Detailed player info
  Future<Map<String, dynamic>> fetchPlayerDetails(String playerId) async {
    final url = Uri.parse("$sportsDbBaseUrl/lookupplayer.php?id=$playerId");
    print("Fetching player details for ID: $playerId");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final players = data['players'];

        if (players != null && players.isNotEmpty) {
          return players.first;
        } else {
          throw Exception("Player not found");
        }
      } else {
        throw Exception("Failed to load player details: ${response.statusCode}");
      }
    } catch (e) {
      print("Error loading player details: $e");
      throw Exception("Error loading player details: $e");
    }
  }
}
