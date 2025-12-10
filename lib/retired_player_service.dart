import 'dart:convert';
import 'package:http/http.dart' as http;

class RetiredPlayerService {
  static const String apiKey = "3"; // Free Tier

  Future<Map<String, dynamic>?> fetchPlayerBasic(String name) async {
    final url = Uri.parse(
        "https://www.thesportsdb.com/api/v1/json/$apiKey/searchplayers.php?p=$name");

    final res = await http.get(url);

    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body);

    if (json["player"] == null || json["player"].isEmpty) {
      return null;
    }

    // Return first matching player
    return json["player"][0];
  }
}
