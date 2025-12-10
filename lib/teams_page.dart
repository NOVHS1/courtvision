import 'package:flutter/material.dart';
import 'team_details_page.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage>
    with SingleTickerProviderStateMixin {
  bool showDivisions = false;

  // ----------------------------------------------------------
  // TEAM DATA
  // ----------------------------------------------------------
  final Map<String, List<Map<String, String>>> conferences = {
    "Eastern Conference": [
      {"team": "Atlanta Hawks", "tri": "ATL"},
      {"team": "Boston Celtics", "tri": "BOS"},
      {"team": "Brooklyn Nets", "tri": "BKN"},
      {"team": "Charlotte Hornets", "tri": "CHA"},
      {"team": "Chicago Bulls", "tri": "CHI"},
      {"team": "Cleveland Cavaliers", "tri": "CLE"},
      {"team": "Detroit Pistons", "tri": "DET"},
      {"team": "Indiana Pacers", "tri": "IND"},
      {"team": "Miami Heat", "tri": "MIA"},
      {"team": "Milwaukee Bucks", "tri": "MIL"},
      {"team": "New York Knicks", "tri": "NYK"},
      {"team": "Orlando Magic", "tri": "ORL"},
      {"team": "Philadelphia 76ers", "tri": "PHI"},
      {"team": "Toronto Raptors", "tri": "TOR"},
      {"team": "Washington Wizards", "tri": "WAS"},
    ],
    "Western Conference": [
      {"team": "Dallas Mavericks", "tri": "DAL"},
      {"team": "Denver Nuggets", "tri": "DEN"},
      {"team": "Golden State Warriors", "tri": "GSW"},
      {"team": "Houston Rockets", "tri": "HOU"},
      {"team": "LA Clippers", "tri": "LAC"},
      {"team": "Los Angeles Lakers", "tri": "LAL"},
      {"team": "Memphis Grizzlies", "tri": "MEM"},
      {"team": "Minnesota Timberwolves", "tri": "MIN"},
      {"team": "New Orleans Pelicans", "tri": "NOP"},
      {"team": "Oklahoma City Thunder", "tri": "OKC"},
      {"team": "Phoenix Suns", "tri": "PHX"},
      {"team": "Portland Trail Blazers", "tri": "POR"},
      {"team": "Sacramento Kings", "tri": "SAC"},
      {"team": "San Antonio Spurs", "tri": "SAS"},
      {"team": "Utah Jazz", "tri": "UTA"},
    ],
  };

  final Map<String, List<Map<String, String>>> divisions = {
    "Atlantic Division": [
      {"team": "Boston Celtics", "tri": "BOS"},
      {"team": "Brooklyn Nets", "tri": "BKN"},
      {"team": "New York Knicks", "tri": "NYK"},
      {"team": "Philadelphia 76ers", "tri": "PHI"},
      {"team": "Toronto Raptors", "tri": "TOR"},
    ],
    "Central Division": [
      {"team": "Chicago Bulls", "tri": "CHI"},
      {"team": "Cleveland Cavaliers", "tri": "CLE"},
      {"team": "Detroit Pistons", "tri": "DET"},
      {"team": "Indiana Pacers", "tri": "IND"},
      {"team": "Milwaukee Bucks", "tri": "MIL"},
    ],
    "Southeast Division": [
      {"team": "Atlanta Hawks", "tri": "ATL"},
      {"team": "Charlotte Hornets", "tri": "CHA"},
      {"team": "Miami Heat", "tri": "MIA"},
      {"team": "Orlando Magic", "tri": "ORL"},
      {"team": "Washington Wizards", "tri": "WAS"},
    ],
    "Northwest Division": [
      {"team": "Denver Nuggets", "tri": "DEN"},
      {"team": "Minnesota Timberwolves", "tri": "MIN"},
      {"team": "Oklahoma City Thunder", "tri": "OKC"},
      {"team": "Portland Trail Blazers", "tri": "POR"},
      {"team": "Utah Jazz", "tri": "UTA"},
    ],
    "Pacific Division": [
      {"team": "Golden State Warriors", "tri": "GSW"},
      {"team": "LA Clippers", "tri": "LAC"},
      {"team": "Los Angeles Lakers", "tri": "LAL"},
      {"team": "Phoenix Suns", "tri": "PHX"},
      {"team": "Sacramento Kings", "tri": "SAC"},
    ],
    "Southwest Division": [
      {"team": "Dallas Mavericks", "tri": "DAL"},
      {"team": "Houston Rockets", "tri": "HOU"},
      {"team": "Memphis Grizzlies", "tri": "MEM"},
      {"team": "New Orleans Pelicans", "tri": "NOP"},
      {"team": "San Antonio Spurs", "tri": "SAS"},
    ],
  };

  // ----------------------------------------------------------
  // TEAM CARD — BIG LOGO + SMALL TILE
  // ----------------------------------------------------------
  Widget _teamCard(Map<String, String> data) {
    final team = data["team"]!;
    final tri = data["tri"]!;

    // Local logos for Pelicans & Jazz
    final Map<String, String> customLogos = {
      "NOP": "assets/logos/NOP.png",
      "UTA": "assets/logos/UTA.png",
    };

    // Detect if team uses a local logo
    final bool isLocal = customLogos.containsKey(tri);

    // Pick asset or ESPN CDN URL
    final String logoPath = isLocal
        ? customLogos[tri]!
        : "https://a.espncdn.com/i/teamlogos/nba/500/$tri.png";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamDetailsPage(
              teamTri: tri,
              teamName: team,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Local asset OR network logo
            isLocal
                ? Image.asset(
                    logoPath,
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    logoPath,
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.error, color: Colors.red),
                  ),
            const SizedBox(height: 6),
            Text(
              team,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  } // 🔧 THIS BRACE WAS MISSING

  // ----------------------------------------------------------
  // PAGE BUILD
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final data = showDivisions ? divisions : conferences;

    // Alphabetical sorting
    final sortedData = data.map((key, list) {
      final sortedList = List<Map<String, String>>.from(list)
        ..sort((a, b) => a["team"]!.compareTo(b["team"]!));
      return MapEntry(key, sortedList);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          showDivisions ? "NBA Divisions" : "NBA Teams",
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => showDivisions = !showDivisions);
            },
            child: Text(
              showDivisions ? "View Conferences" : "View Divisions",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          ...sortedData.entries.map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entry.value.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,      // 3 columns
                      childAspectRatio: 1.25, // smaller tiles
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, i) =>
                        _teamCard(entry.value[i]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
