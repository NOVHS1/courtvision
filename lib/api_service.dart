import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiService {
  // API keys & base URLs
  final String apiKey = "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k";
  final String sportsDbBaseUrl = "https://www.thesportsdb.com/api/v1/json/3";
  final String functionUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/fetchNBAGames";

  // Firestore reference
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch today's NBA games from Sportradar
  Future<List<dynamic>> fetchTodayGames() async {
    final now = DateTime.now();
    final year = DateFormat('yyyy').format(now);
    final month = DateFormat('MM').format(now);
    final day = DateFormat('dd').format(now);

    final url = Uri.parse(
      "https://api.sportradar.us/nba/trial/v8/en/games/$year/$month/$day/schedule.json?api_key=$apiKey",
    );

    print("Fetching NBA schedule from: $url");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['games'] ?? [];
      } else {
        throw Exception("Error ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error loading games: $e");
    }
  }

  // REFRESH NBA GAMES via Firebase Cloud Function (for HomePage refresh)
  Future<void> refreshNBAGames() async {
    try {
      print("🔄 Refreshing NBA games via Cloud Function...");
      final response = await http.get(Uri.parse(functionUrl));
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

  // Search NBA players by name (SportsDB)
  Future<List<dynamic>> searchNBAPlayers(String name) async {
    final url = Uri.parse("$sportsDbBaseUrl/searchplayers.php?p=$name");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final players = data['player'] ?? [];

      // Filter to basketball players only
      return players
          .where((p) =>
              p['strSport']?.toLowerCase() == 'basketball' &&
              (p['strTeam'] ?? '').isNotEmpty)
          .toList();
    } else {
      throw Exception("Failed to search NBA players");
    }
  }

  // Fetch a specific team’s roster (SportsDB)
  Future<List<dynamic>> fetchTeamRoster(String teamId) async {
    final url =
        Uri.parse("$sportsDbBaseUrl/lookup_all_players.php?id=$teamId");
    print("📡 Fetching roster for team ID: $teamId");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final players = data['player'] ?? [];

        // Only include basketball players
        return players
            .where((p) => p['strSport']?.toLowerCase() == 'basketball')
            .toList();
      } else {
        throw Exception("Failed to fetch roster: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error loading roster: $e");
    }
  }

  //Fetch all NBA players & cache to Firestore
  Future<List<dynamic>> fetchAllNBAPlayers({bool forceRefresh = false}) async {
    final List<dynamic> allPlayers = [];

    // Check Firestore cache first
    if (!forceRefresh) {
      final snapshot = await _firestore.collection('nba_players').get();
      if (snapshot.docs.isNotEmpty) {
        print("⚡ Loaded ${snapshot.docs.length} cached players from Firestore");
        return snapshot.docs.map((d) => d.data()).toList();
      }
    }

    // Fetch all NBA teams
    print("Fetching all NBA teams...");
    final teamsUrl =
        Uri.parse("$sportsDbBaseUrl/search_all_teams.php?l=NBA");
    final teamsResponse = await http.get(teamsUrl);

    if (teamsResponse.statusCode != 200) {
      throw Exception("Failed to load NBA teams");
    }

    final teamsData = json.decode(teamsResponse.body);
    final teams = teamsData['teams'] ?? [];

    print("Found ${teams.length} NBA teams");

    // Step 3️⃣: Loop through all teams
    for (var team in teams) {
      final teamId = team['idTeam'];
      final teamName = team['strTeam'];

      final playersUrl =
          Uri.parse("$sportsDbBaseUrl/lookup_all_players.php?id=$teamId");
      print("Fetching players for $teamName...");
      final playersResponse = await http.get(playersUrl);

      if (playersResponse.statusCode == 200) {
        final playersData = json.decode(playersResponse.body);
        final players = playersData['player'] ?? [];

        for (var player in players) {
          if (player['strSport']?.toLowerCase() == 'basketball') {
            allPlayers.add(player);

            // Save or update each player in Firestore
            await _firestore
                .collection('nba_players')
                .doc(player['idPlayer'])
                .set(player, SetOptions(merge: true));
          }
        }
      }
    }

    print("Total NBA players fetched and cached: ${allPlayers.length}");
    return allPlayers;
  }

  // Fetch detailed player profile (for Player Details Page)
  Future<Map<String, dynamic>> fetchPlayerDetails(String playerId) async {
    final url =
        Uri.parse("$sportsDbBaseUrl/lookupplayer.php?id=$playerId");
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
      throw Exception("Failed to load player details");
    }
  }
}
