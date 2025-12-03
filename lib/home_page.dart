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
    final user = FirebaseAuth.instance.currentUser;

    final gamesStream = FirebaseFirestore.instance
        .collection('nba_games')
        .orderBy('updatedAt')
        .limit(15)
        .snapshots(); // <- No limit so all cached games show

     // 🔵 Listening for the first document date
    gamesStream.listen((event) {
      if (event.docs.isNotEmpty) {
        final first = event.docs.first.data() as Map<String, dynamic>;
        setState(() {
          nextGameDate = first["scheduledUTC"]?.toString().substring(0, 10);
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('CourtVision',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            )),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows, size: 26),
            onPressed: () {
              Navigator.push(
                context, MaterialPageRoute(builder: (context) => const PlayerComparePage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          if (user == null)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/auth'),
              child: const Text('Sign In', style: TextStyle(color: Colors.white)),
            ),
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              },
            ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: gamesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("Loading cached games...",
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No games found in cache.",
                  style: TextStyle(fontSize: 16)),
            );
          }

          final games = snapshot.data!.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          return _buildHomeLayout(games);
        },
      ),
    );
  }


// -----------------------------
// HOME PAGE LAYOUT
// -----------------------------

  // FULL NBA.COM STYLE HOME LAYOUT
  Widget _buildHomeLayout(List<dynamic> games) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HERO BANNER
          _buildHeroBanner(),

          const SizedBox(height: 24),

          _buildTodaysGames(games),

          // TODAY'S GAMES STRIP
          _buildTodaysGames(games),

          const SizedBox(height: 32),

          // TRENDING PLAYERS SECTION
          _buildTrendingPlayersSection(),
          const SizedBox(height: 32),
          _buildLeagueLeadersSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
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
  
      final formatted = DateFormat('MMM d').format(DateTime.parse(nextGameDate!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        "Next Games — $formatted", // 🔵 UPDATED
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // HERO BANNER (NBA.com style)
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1D9BF0),
            Color(0xFF0A4AA6),
          ],
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
            "Real-time stats • Player comparisons • Game analytics",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }


  // -----------------------------
  // GAMES CAROUSEL
  // -----------------------------
// TODAY'S GAMES CAROUSEL STRIP
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
            final game = games[index] as Map<String, dynamic>;

            final home = game["home"];
            final away = game["away"];

            final homeTeam = game["home"]["name"];
            final awayTeam = game["away"]["name"];

            final homeTri = game["home"]["triCode"] ?? "";
            final awayTri = game["away"]["triCode"] ?? "";

            // ESPN LOGO BUILDER 🔵 NEW
            final homeLogo =
                  "https://a.espncdn.com/i/teamlogos/nba/500/$homeTri.png";
            final awayLogo =
                  "https://a.espncdn.com/i/teamlogos/nba/500/$awayTri.png";

            final homeScore = game["home"]["score"].toString();
            final awayScore = game["away"]["score"].toString();

            final status = game["status"]?.toLowerCase() ?? "";
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
                    // 🔵 TEAM LOGOS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Image.network(awayLogo, height: 40, width: 40),
                        const Text("vs", style: TextStyle(color: Colors.white)),
                        Image.network(homeLogo, height: 40, width: 40),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 🔵 TEAM NAMES
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

                    // 🔵 SCORE OR TIME
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

  // -----------------------------
  // TRENDING PLAYERS
  // -----------------------------

  // TRENDING PLAYERS ROW
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

  // -----------------------------
  // PLAYER CARD
  // -----------------------------

  // PLAYER CARD (used for Trending section)
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
          Text(name,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // -----------------------------
  // LEAGUE LEADERS
  // -----------------------------

  // LEAGUE LEADERS PREVIEW
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