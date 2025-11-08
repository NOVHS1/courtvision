import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Base URLs
  final String sportsDbBaseUrl = "https://www.thesportsdb.com/api/v1/json/657478";
  final String fetchNBAGamesUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/fetchNBAGames";
  final String searchPlayersUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/searchPlayers";
  final String getPlayerStatsUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/getPlayerStats";

  // Fetch today’s NBA games (via Cloud Function)
  Future<List<dynamic>> fetchTodayGames() async {
    final now = DateTime.now().toUtc();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final url = Uri.parse("$fetchNBAGamesUrl?date=$date");

    print("Fetching NBA schedule from Cloud Function: $url");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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

  // Trigger backend refresh for stored games
  Future<void> refreshNBAGames() async {
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

  // Search NBA players (SportsDB)
  Future<List<dynamic>> searchNBAPlayers(String name) async {
    final uri = Uri.parse("$sportsDbBaseUrl/searchplayers.php?p=$name");
    print("Searching NBA players: $name");

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['player'] ?? [];
      }
      throw Exception("Search failed: ${response.statusCode}");
    } catch (e) {
      print("Error searching players: $e");
      rethrow;
    }
  }

  // Get player stats (via Cloud Function + safe handling)
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

        if (data is Map<String, dynamic> && data.isNotEmpty) {
          print("Player stats successfully fetched for $playerId");
          return data;
        }

        print("Empty or invalid stats data for $playerId");
        return null;
      } else {
        print("Failed to load player stats: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching player stats: $e");
      return null;
    }
  }

  // Fetch all NBA players and cache in Firestore
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
      final teamName = team['strTeam'];

      await Future.delayed(const Duration(milliseconds: 700));
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

  // Fetch a specific team’s roster (SportsDB)
  Future<List<dynamic>> fetchTeamRoster(String teamId) async {
    final url = Uri.parse("$sportsDbBaseUrl/lookup_all_players.php?id=$teamId");
    print("Fetching roster for team ID: $teamId");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final players = data['player'] ?? [];

        return players
            .where((p) => p['strSport']?.toLowerCase() == 'basketball')
            .toList();
      } else {
        throw Exception("Failed to fetch roster: ${response.statusCode}");
      }
    } catch (e) {
      print("Error loading roster: $e");
      throw Exception("Error loading roster: $e");
    }
  }

  // Fetch detailed player profile (SportsDB)
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
