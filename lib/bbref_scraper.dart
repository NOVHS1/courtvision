import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;

class BBRefScraper {
  Future<Map<String, dynamic>?> fetchCareerStats(String playerCode) async {
    if (playerCode.isEmpty) return null;

    final first = playerCode[0].toLowerCase();
    final url = Uri.parse(
      "https://www.basketball-reference.com/players/$first/$playerCode.html",
    );

    final res = await http.get(
      url,
      headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept":
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Connection": "keep-alive",
      },
    );

    if (res.statusCode != 200) {
      print("BBRef HTTP error: ${res.statusCode} for $url");
      return null;
    }

    final document = html.parse(res.body);
    final Map<String, dynamic> data = {};

    // -------------------------------
    // Career totals table (#totals)
    // -------------------------------
    final careerTotalsTable = document.querySelector("#totals");

    if (careerTotalsTable != null) {
      final rows = careerTotalsTable.querySelectorAll("tbody tr");
      final List<Map<String, dynamic>> seasons = [];

      for (final row in rows) {
        final seasonCell = row.querySelector("th");
        final season = seasonCell?.text.trim() ?? "";

        if (season.isEmpty || season == "Career") {
          continue; // skip blank & summary row
        }

        String _cell(String stat) =>
            row.querySelector('[data-stat="$stat"]')?.text.trim() ?? "";

        final seasonStats = {
          "season": season,
          "team": _cell("team_id"),
          "games": _cell("g"),
          "points": _cell("pts"),
          "rebounds": _cell("trb"),
          "assists": _cell("ast"),
        };

        seasons.add(seasonStats);
      }

      data["career_totals"] = seasons;
    } else {
      print("BBRef: #totals table not found for $playerCode");
    }

    // -------------------------------
    // Awards (#bling)
    // -------------------------------
    final awardsDiv = document.querySelector("#bling");
    if (awardsDiv != null) {
      data["awards"] = awardsDiv.text
          .replaceAll("\n", " ")
          .replaceAll("  ", " ")
          .trim();
    }

    return data;
  }
}
