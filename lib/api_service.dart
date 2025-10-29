import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ApiService {
  final String apiKey = "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k";

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
      print("🔥 Exception during fetch: $e");
      throw Exception("Error loading games: $e");
    }
  }
}
