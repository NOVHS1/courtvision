import 'package:flutter/material.dart';

class TeamDetailsPage extends StatelessWidget {
  final String teamTri;
  final String teamName;

  const TeamDetailsPage({
    super.key,
    required this.teamTri,
    required this.teamName,
  });

  // ----------------------------------------------------------
  // TEAM COLORS (simple theme — replace later if you want exact team colors)
  // ----------------------------------------------------------
  Color get primaryColor {
    switch (teamTri) {
      case "LAL":
        return const Color(0xFF552583);
      case "GSW":
        return const Color(0xFF006BB6);
      case "MIA":
        return const Color(0xFF98002E);
      case "BOS":
        return const Color(0xFF007A33);
      case "NOP":
        return const Color(0xFF002B5C);
      case "UTA":
        return const Color(0xFF002B5C);
      default:
        return const Color(0xFF1D9BF0);
    }
  }

  Color get secondaryColor => primaryColor.withOpacity(0.6);

  // ----------------------------------------------------------
  // LOGO SOURCE (local fix for NOP and UTA)
  // ----------------------------------------------------------
  String get logoPath {
    if (teamTri == "NOP") return "assets/logos/NOP.png";
    if (teamTri == "UTA") return "assets/logos/UTA.png";

    return "https://a.espncdn.com/i/teamlogos/nba/500/$teamTri.png";
  }

  bool get isLocal => teamTri == "NOP" || teamTri == "UTA";

  // ----------------------------------------------------------
  // PLACEHOLDER TEAM STATS (replace with Firestore/API later)
  // ----------------------------------------------------------
  Map<String, dynamic> get teamStats => {
        "record": "32 - 18",
        "ppg": 118.4,
        "apg": 27.8,
        "rpg": 45.2,
        "defRank": 7,
        "netRating": "+4.2",
      };

  // ----------------------------------------------------------
  // PLACEHOLDER GAME DATA
  // ----------------------------------------------------------
  List<Map<String, String>> get lastGames => [
        {"opponent": "LAL", "result": "W 122-118"},
        {"opponent": "DEN", "result": "L 104-112"},
        {"opponent": "GSW", "result": "W 130-121"},
        {"opponent": "PHX", "result": "W 116-109"},
        {"opponent": "MEM", "result": "L 99-107"},
      ];

  List<Map<String, String>> get nextGames => [
        {"opponent": "SAC", "date": "Feb 10"},
        {"opponent": "HOU", "date": "Feb 12"},
        {"opponent": "DAL", "date": "Feb 14"},
        {"opponent": "UTA", "date": "Feb 16"},
        {"opponent": "POR", "date": "Feb 18"},
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          teamName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 20),

            _buildTeamStats(),
            const SizedBox(height: 20),

            _buildLastFiveGames(),
            const SizedBox(height: 20),

            _buildNextFiveGames(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // HERO HEADER (logo + team name + record)
  // ----------------------------------------------------------
  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            secondaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),

      child: Column(
        children: [
          isLocal
              ? Image.asset(logoPath, height: 140)
              : Image.network(logoPath, height: 140),

          const SizedBox(height: 16),

          Text(
            teamName,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Record: ${teamStats["record"]}",
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // TEAM STATS GRID
  // ----------------------------------------------------------
  Widget _buildTeamStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Team Stats",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              children: [
                _statTile("PPG", teamStats["ppg"].toString()),
                _statTile("APG", teamStats["apg"].toString()),
                _statTile("RPG", teamStats["rpg"].toString()),
                _statTile("DEF Rank", "#${teamStats["defRank"]}"),
                _statTile("Net Rating", teamStats["netRating"]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // LAST 5 GAMES
  // ----------------------------------------------------------
  Widget _buildLastFiveGames() {
    return _gameSection(
      title: "Last 5 Games",
      children: lastGames.map((g) {
        return ListTile(
          leading: _smallTeamLogo(g["opponent"]!),
          title: Text(
            g["result"]!,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------------------
  // UPCOMING GAMES
  // ----------------------------------------------------------
  Widget _buildNextFiveGames() {
    return _gameSection(
      title: "Upcoming Games",
      children: nextGames.map((g) {
        return ListTile(
          leading: _smallTeamLogo(g["opponent"]!),
          title: Text(
            g["date"]!,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------------------
  // GENERIC GAME SECTION TEMPLATE
  // ----------------------------------------------------------
  Widget _gameSection({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Column(children: children),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // SMALL LOGO FOR GAMES LIST
  // ----------------------------------------------------------
  Widget _smallTeamLogo(String tri) {
    if (tri == "NOP") {
      return Image.asset("assets/logos/NOP.png", height: 28, width: 28);
    }
    if (tri == "UTA") {
      return Image.asset("assets/logos/UTA.png", height: 28, width: 28);
    }

    return Image.network(
      "https://a.espncdn.com/i/teamlogos/nba/500/$tri.png",
      height: 28,
      width: 28,
    );
  }
}
