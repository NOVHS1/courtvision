import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ApiService {
  final String apiKey = "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k";
  final String functionUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/fetchNBAGames";

  Future<List<dynamic>> fetchTodayGames() async {
    final now = DateTime.now();
    final year = DateFormat('yyyy').format(now);
    final month = DateFormat('MM').format(now);
    final day = DateFormat('dd').format(now);

    final url = Uri.parse(
      "https://api.sportradar.us/nba/trial/v8/en/games/$year/$month/$day/schedule.json?api_key=$apiKey",
    );

    print("📡 Fetching NBA schedule from: $url");

    try {
      final response = await http.get(url);
      print("Status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final games = data['games'] ?? [];

        if (games.isEmpty) {
          print("ℹNo NBA games found for $year-$month-$day");
        } else {
          print("Found ${games.length} games");
        }

        return games;
      } else {
        // When API returns an error code
        print("Error from Sportradar: ${response.body}");
        throw Exception("API error: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception during fetch: $e");
      throw Exception("Error loading games: $e");
    }
  }

  // Fetch team roster from Sportradar API
  Future<List<dynamic>> fetchTeamRoster(String teamId) async {
    final formattedId = teamId.replaceAll("sr:team:", "").trim();

    final url = Uri.parse(
      "https://api.sportradar.us/nba/trial/v8/en/teams/$formattedId/profile.json?api_key=$apiKey",
    );

    print("Fetching roster for team: $teamId");
    print("URL: $url");

    try {
      final response = await http.get(url, headers: {'x-api-key': apiKey});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final players = data['players'] ?? [];
        print("Found ${players.length} players for team $formattedId");

        return players;
      } else if (response.statusCode == 403) {
        throw Exception(
          "Access denied: Your API key may not include Team Profile access.",
        );
      } else if (response.statusCode == 404) {
        throw Exception("Team not found: $formattedId");
      } else {
        print("Response body: ${response.body}");
        throw Exception(
          "Error ${response.statusCode}: ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      throw Exception("Error loading roster: $e");
    }
  }

  Future<void> refreshNBAGames() async {
    try {
      final response = await http.get(Uri.parse(functionUrl));
      if (response.statusCode == 200) {
        print("Successfully refreshed NBA games in Firestore");
      } else {
        throw Exception("Failed to refresh games: ${response.statusCode}");
      }
    } catch (e) {
      print("Error calling Cloud Function: $e");
      rethrow;
    }
  }
}
