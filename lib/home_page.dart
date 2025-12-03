import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'search_page.dart';
import 'game_details_page.dart';
import 'player_compare_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? nextGameDate;

  @override
  Widget build(BuildContext context) {
    print("HomePage built");

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  title: const Text(
    "CourtVision",
    style: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
    ),
  ),
  actions: [
    // Player Comparison Button
    IconButton(
      icon: const Icon(Icons.compare_arrows, size: 26),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlayerComparePage()),
        );
      },
    ),

    // Search Page Button
    IconButton(
      icon: const Icon(Icons.search, size: 26),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        );
      },
    ),

    // Login / Logout
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
                const SnackBar(content: Text("Logged out successfully")),
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
          print("STREAM EVENT RECEIVED");

          if (snapshot.hasError) {
            print("FIRESTORE ERROR: ${snapshot.error}");
            return const Center(child: Text("Firestore Error"));
          }

          if (!snapshot.hasData) {
            print("NO DATA YET");
            return const Center(child: Text("Waiting for data…"));
          }

          final docs = snapshot.data!.docs;
          print("SNAPSHOT DOC COUNT: ${docs.length}");

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
  // HEADER
  // -----------------------------------------------------
  Widget _buildNextGamesHeader() {
    if (nextGameDate == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          "Upcoming Games",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );
    }

    final formatted =
        DateFormat('MMM d').format(DateTime.parse(nextGameDate!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        "Next Games — $formatted",
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // HERO BANNER
  // -----------------------------------------------------
  Widget _buildHeroBanner() {
    return Container(
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
    );
  }

  // -----------------------------------------------------
  // TODAY’S GAMES
  // -----------------------------------------------------
  Widget _buildTodaysGames(List<dynamic> games) {
    final today = DateFormat('MMM d').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Today's Games — $today",
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];

              final home = game["home"];
              final away = game["away"];

              final homeTeam = home["name"];
              final awayTeam = away["name"];

              final homeTri = home["triCode"];
              final awayTri = away["triCode"];

              final homeLogo =
                  "https://a.espncdn.com/i/teamlogos/nba/500/$homeTri.png";
              final awayLogo =
                  "https://a.espncdn.com/i/teamlogos/nba/500/$awayTri.png";

              final homeScore = home["score"].toString();
              final awayScore = away["score"].toString();

              final status = (game["status"] ?? "").toLowerCase();
              final isFinal = status.contains("final");

              final scheduledUTC = game["scheduledUTC"] ?? "";

              String timeText = "TBD";
              if (scheduledUTC.contains("T")) {
                final t = scheduledUTC.split("T")[1];
                timeText = t.substring(0, 5);
              }

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailsPage(gameData: game),
                  ),
                ),
                child: Container(
                  width: 250,
                  margin: const EdgeInsets.only(left: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Image.network(awayLogo, height: 40, width: 40),
                          const Text("vs",
                              style: TextStyle(color: Colors.white)),
                          Image.network(homeLogo, height: 40, width: 40),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "$awayTeam @ $homeTeam",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFinal ? "$awayScore - $homeScore" : timeText,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
              _playerCard("LeBron James",
                  "https://cdn.nba.com/headshots/nba/latest/260x190/2544.png"),
              _playerCard("Stephen Curry",
                  "https://cdn.nba.com/headshots/nba/latest/260x190/201939.png"),
              _playerCard("Jayson Tatum",
                  "https://cdn.nba.com/headshots/nba/latest/260x190/1628369.png"),
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
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // LEAGUE LEADERS
  // -----------------------------------------------------
  Widget _buildLeagueLeadersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("League Leaders",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("PPG • APG • RPG • FG% • 3P% • More",
                style: TextStyle(fontSize: 15, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
