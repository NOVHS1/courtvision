import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_page.dart';
import 'game_details_page.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final gamesStream = FirebaseFirestore.instance
        .collection('nba_games')
        .orderBy('scheduled')
        .limit(5)
        .snapshots(); // <- No limit so all cached games show

    return Scaffold(
      appBar: AppBar(
        title: const Text('CourtVision Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
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

          return _buildGamesGrid(games);
        },
      ),
    );
  }

  Widget _buildGamesGrid(List<dynamic> games) {
    final todayLabel = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "🗓 Games (Cached Data Mode)",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.9,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final gameData = games[index] as Map<String, dynamic>;

                final homeTeam = gameData['home']?['name'] ?? 'Home';
                final awayTeam = gameData['away']?['name'] ?? 'Away';

                String alias(String team) {
                  final map = {
                    'los angeles lakers': 'lal',
                    'golden state warriors': 'gsw',
                    'boston celtics': 'bos',
                    'miami heat': 'mia',
                    'new york knicks': 'nyk',
                    'brooklyn nets': 'bkn',
                    'phoenix suns': 'phx',
                    'chicago bulls': 'chi',
                    'philadelphia 76ers': 'phi',
                    'denver nuggets': 'den',
                    'milwaukee bucks': 'mil',
                    'memphis grizzlies': 'mem',
                    'dallas mavericks': 'dal',
                    'sacramento kings': 'sac',
                    'cleveland cavaliers': 'cle',
                    'new orleans pelicans': 'nop',
                    'portland trail blazers': 'por',
                    'minnesota timberwolves': 'min',
                    'oklahoma city thunder': 'okc',
                    'atlanta hawks': 'atl',
                    'orlando magic': 'orl',
                    'san antonio spurs': 'sas',
                    'washington wizards': 'was',
                    'toronto raptors': 'tor',
                    'detroit pistons': 'det',
                    'indiana pacers': 'ind',
                    'utah jazz': 'uta',
                    'charlotte hornets': 'cha',
                    'houston rockets': 'hou',
                    'los angeles clippers': 'lac',
                  };
                  return map[team.toLowerCase()] ??
                      team.split(' ').last.toLowerCase();
                }

                final homeLogo =
                    "https://a.espncdn.com/i/teamlogos/nba/500/${alias(homeTeam)}.png";
                final awayLogo =
                    "https://a.espncdn.com/i/teamlogos/nba/500/${alias(awayTeam)}.png";

                final status = gameData['status'] ?? 'scheduled';
                final homeScore = gameData['home_points'] ?? '-';
                final awayScore = gameData['away_points'] ?? '-';
                final scheduled = gameData['scheduled']?.toString() ?? '';
                final timeText = scheduled.contains('T')
                    ? scheduled.split('T')[1].substring(0, 5)
                    : 'TBD';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GameDetailsPage(gameData: gameData),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Image.network(awayLogo, height: 40, width: 40),
                              const Text(
                                "VS",
                                style: TextStyle(color: Colors.white),
                              ),
                              Image.network(homeLogo, height: 40, width: 40),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              "$awayTeam vs $homeTeam",
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            status == 'closed'
                                ? "$awayScore - $homeScore"
                                : "$timeText",
                            style: TextStyle(
                              color: status == 'closed'
                                  ? Colors.greenAccent
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
