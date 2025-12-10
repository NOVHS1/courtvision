import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'search_page.dart';
import 'game_details_page.dart';
import 'player_compare_page.dart';
import 'teams_page.dart';
import 'account_page.dart';

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

  int _selectedDay = 1;

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
  // Teams
  IconButton(
    icon: const Icon(Icons.list, size: 26, color: Colors.white),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeamsPage()),
      );
    },
  ),

  // Compare
  IconButton(
    icon: const Icon(Icons.compare_arrows, size: 26),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayerComparePage()),
      );
    },
  ),

  // Search
  IconButton(
    icon: const Icon(Icons.search, size: 26),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchPage()),
      );
    },
  ),

  // -----------------------------
  // SIGN IN or ACCOUNT ICON
  // -----------------------------
  StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      final user = snapshot.data;

      if (user == null) {
        // USER NOT LOGGED IN → SHOW SIGN IN BUTTON
        return TextButton(
          onPressed: () => Navigator.pushNamed(context, '/auth'),
          child: const Text(
            "Sign In",
            style: TextStyle(color: Colors.white),
          ),
        );
      } else {
        // USER LOGGED IN → SHOW ACCOUNT BUTTON
        return IconButton(
          icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountPage()),
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
    final filteredGames = _filterGamesWindow(games);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroBanner(),
          const SizedBox(height: 24),
          _buildTodaysGames(filteredGames),
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

  DateTime _getDayForTab() {
  final today = DateTime.now();

  if (_selectedDay == 0) return today.subtract(const Duration(days: 1));
  if (_selectedDay == 2) return today.add(const Duration(days: 1));

  return today; // selectedDay == 1 -> Today
}


List<dynamic> _filterGamesWindow(List<dynamic> games) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final start = today.subtract(const Duration(days: 3)); // 3 days before
  final end   = today.add(const Duration(days: 3));       // 3 days after

  return games.where((game) {
    final raw = game["scheduledUTC"] ?? "";
    if (!raw.contains("T")) return false;

    DateTime? gDate;
    try {
      gDate = DateTime.parse(raw);
    } catch (e) {
      return false;
    }

    final gameDay = DateTime(gDate.year, gDate.month, gDate.day);

    final inRange =
        gameDay.isAtSameMomentAs(start) ||
        gameDay.isAtSameMomentAs(end) ||
        (gameDay.isAfter(start) && gameDay.isBefore(end));

    return inRange;
  }).toList();
}

List<dynamic> _filterGamesForSelectedDay(List<dynamic> games) {
  final selectedDay = _getDayForTab();
  final dayStart = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  return games.where((game) {
    final raw = game["scheduledUTC"];
    if (raw == null) return false;

    DateTime? gameDate;
    try {
      gameDate = DateTime.parse(raw);
    } catch (_) {
      return false;
    }

    return gameDate.isAfter(dayStart) && gameDate.isBefore(dayEnd);
  }).toList();
}

  // -----------------------------------------------------
  // TODAY’S GAMES
  // -----------------------------------------------------
Widget _buildTodaysGames(List<dynamic> games) {
  final selectedGames = _filterGamesForSelectedDay(games);
  final selectedDate = _getDayForTab();
  final label = DateFormat('EEEE, MMM d').format(selectedDate);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ---------- TABS ----------
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ToggleButtons(
              isSelected: [
                _selectedDay == 0,
                _selectedDay == 1,
                _selectedDay == 2,
              ],
              borderRadius: BorderRadius.circular(10),
              selectedColor: Colors.white,
              color: Colors.grey,
              fillColor: Colors.white12,
              onPressed: (index) {
                setState(() => _selectedDay = index);
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text("Yesterday"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text("Today"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text("Tomorrow"),
                ),
              ],
            ),

            // Scroll arrows
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left, color: Colors.white, size: 32),
                  onPressed: () => _scrollGamesList(-300),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right, color: Colors.white, size: 32),
                  onPressed: () => _scrollGamesList(300),
                ),
              ],
            )
          ],
        ),
      ),

      const SizedBox(height: 8),

      // ---------- DATE LABEL ----------
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      const SizedBox(height: 12),

      // ---------- GAME LIST ----------
      SizedBox(
        height: 150,
        child: selectedGames.isEmpty
            ? const Center(
                child: Text(
                  "No games on this day",
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : ListView.builder(
                controller: _gamesScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: selectedGames.length,
                itemBuilder: (context, index) {
                  final game = selectedGames[index];
                  return _smallGameCard(game, "");
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
