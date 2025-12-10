import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'search_page.dart';
import 'game_details_page.dart';
import 'player_compare_page.dart';
import 'teams_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? nextGameDate;

  late AnimationController _heroController;
  late Animation<double> _heroFade;

  final ScrollController _gamesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _heroFade = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "CourtVision",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list, size: 26, color: Colors.white),
            onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamsPage()),
            );
        },
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlayerComparePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          ),
          Builder(
            builder: (context) {
              final user = FirebaseAuth.instance.currentUser;

              if (user == null) {
                return TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/auth');
                  },
                  child: const Text(
                    "Sign In",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Logged out successfully")),
                    );
                  },
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("nba_games")
            .orderBy("scheduledUTC")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Firestore Error"));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("Waiting for data…"));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No games found in Firestore.",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          final games = docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList();

          return _buildHomeLayout(games);
        },
      ),
    );
  }

  // -----------------------------------------------------
  // MAIN LAYOUT
  // -----------------------------------------------------
  Widget _buildHomeLayout(List<dynamic> games) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroBanner(),
          const SizedBox(height: 24),
          _buildTodaysGames(games),
          const SizedBox(height: 32),
          _buildTrendingPlayersSection(),
          const SizedBox(height: 32),
          _buildLeagueLeadersSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // HERO BANNER
  // -----------------------------------------------------
  Widget _buildHeroBanner() {
    return FadeTransition(
      opacity: _heroFade,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D9BF0), Color(0xFF0A4AA6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your Home for Basketball Insights",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Real-time Stats • Player Comparisons • Game Analytics",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // TODAY’S GAMES
  // -----------------------------------------------------
Widget _buildTodaysGames(List<dynamic> games) {
  final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Games",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            // ADDED — LEFT & RIGHT ARROWS
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left, color: Colors.white, size: 32),
                  onPressed: () => _scrollGamesList(-300), // scroll LEFT
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right, color: Colors.white, size: 32),
                  onPressed: () => _scrollGamesList(300), // scroll RIGHT
                ),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 12),

      SizedBox(
        height: 150,
        child: ListView.builder(
          controller: _gamesScrollController, // ADDED
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return _smallGameCard(game, todayString);
          },
        ),
      ),
    ],
  );
}

// -----------------------------------------------------
// SMALLER GAME CARD (NBA.com style)
// -----------------------------------------------------
Widget _smallGameCard(dynamic game, String todayString) {  // MODIFIED
  final home = game["home"];
  final away = game["away"];

  final homeTeam = home["name"];
  final awayTeam = away["name"];

  final homeTri = home["triCode"];
  final awayTri = away["triCode"];

  final Map<String, String> customLogos = {
    "NOP": "assets/logos/NOP.png",
    "UTA": "assets/logos/UTA.png",
  };

   final bool isHomeLocal = customLogos.containsKey(homeTri);
  final bool isAwayLocal = customLogos.containsKey(awayTri);

  final String homeLogo = isHomeLocal
      ? customLogos[homeTri]!
      : "https://a.espncdn.com/i/teamlogos/nba/500/$homeTri.png";

  final String awayLogo = isAwayLocal
      ? customLogos[awayTri]!
      : "https://a.espncdn.com/i/teamlogos/nba/500/$awayTri.png";

  final String statusRaw = (game["status"] ?? "TBD").toString();
  final String gameDateText = statusRaw;                      

  final homeScore = home["score"].toString();
  final awayScore = away["score"].toString();

  final isFinal = statusRaw.toLowerCase().contains("final");

  return GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameDetailsPage(gameData: game)),
    ),
    child: Container(
      width: 180,                // smaller width
      margin: const EdgeInsets.only(left: 16, right: 4),
      padding: const EdgeInsets.all(10), // MODIFIED (tighter padding)
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12), // smaller corner radius
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // smaller NBA.com style logos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              isAwayLocal
                  ? Image.asset(awayLogo, height: 40, width: 40)
                  : Image.network(
                      awayLogo,
                      height: 40,
                      width: 40,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.error, color: Colors.red),
                    ),

              const Text("vs", style: TextStyle(color: Colors.white)),

              isHomeLocal
                  ? Image.asset(homeLogo, height: 40, width: 40)
                  : Image.network(
                      homeLogo,
                      height: 40,
                      width: 40,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.error, color: Colors.red),
                    ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            "$awayTeam @ $homeTeam",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,         // smaller text
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            isFinal ? "$awayScore - $homeScore" : gameDateText,    
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,         // smaller text
            ),
          ),
        ],
      ),
    ),
  );
}

// ADDED — Smooth Scroll Function
void _scrollGamesList(double offset) {
  _gamesScrollController.animateTo(
    _gamesScrollController.offset + offset,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}

  // -----------------------------------------------------
  // TRENDING PLAYERS
  // -----------------------------------------------------
  Widget _buildTrendingPlayersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Trending Players",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _playerCard(
                "LeBron James",
                "https://cdn.nba.com/headshots/nba/latest/260x190/2544.png",
              ),
              _playerCard(
                "Stephen Curry",
                "https://cdn.nba.com/headshots/nba/latest/260x190/201939.png",
              ),
              _playerCard(
                "Jayson Tatum",
                "https://cdn.nba.com/headshots/nba/latest/260x190/1628369.png",
              ),
            ],
          ),
        )
      ],
    );
  }

  // -----------------------------------------------------
  // PLAYER CARD
  // -----------------------------------------------------
  Widget _playerCard(String name, String imageUrl) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          CircleAvatar(radius: 40, backgroundImage: NetworkImage(imageUrl)),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // LEAGUE LEADERS – PLACEHOLDER DATA
  // -----------------------------------------------------
  Widget _buildLeagueLeadersSection() {
    final leaders = [
      {
        "name": "Luka Dončić",
        "team": "DAL",
        "ppg": 34.1,
        "photo":
            "https://cdn.nba.com/headshots/nba/latest/260x190/1629029.png",
      },
      {
        "name": "Giannis Antetokounmpo",
        "team": "MIL",
        "ppg": 32.0,
        "photo":
            "https://cdn.nba.com/headshots/nba/latest/260x190/203507.png",
      },
      {
        "name": "Kevin Durant",
        "team": "PHX",
        "ppg": 30.2,
        "photo":
            "https://cdn.nba.com/headshots/nba/latest/260x190/201142.png",
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "League Leaders – Points",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...leaders.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(p["photo"] as String),
                ),
                title: Text(
                  p["name"] as String,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  "${p["team"]} • ${p["ppg"]} PPG",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
