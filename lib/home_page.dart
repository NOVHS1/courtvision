import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_stats_page.dart';
import 'search_page.dart';
import 'game_details_page.dart';
import 'api_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final apiService = ApiService();

    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final gamesStream = FirebaseFirestore.instance
        .collection('nba_games')
        .where(
          'scheduled',
          isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
          isLessThan: endOfDay.toIso8601String(),
        )
        .orderBy('scheduled')
        .snapshots();

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
              onPressed: () {
                Navigator.pushNamed(context, '/auth');
              },
              child: const Text(
                'Sign In',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
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
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No games scheduled for today."));
          }

          final games = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final gameData = games[index].data() as Map<String, dynamic>;
                final homeTeam = gameData['home']?['name'] ?? 'Home';
                final awayTeam = gameData['away']?['name'] ?? 'Away';

                final homeLogo =
                    "https://a.espncdn.com/i/teamlogos/nba/500/${gameData['home']?['alias']?.toLowerCase() ?? 'nba'}.png";
                final awayLogo =
                    "https://a.espncdn.com/i/teamlogos/nba/500/${gameData['away']?['alias']?.toLowerCase() ?? 'nba'}.png";

                final scheduled = (gameData['scheduled'] ?? 'No Time')
                    .toString()
                    .substring(11, 16);

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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    color: Colors.grey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Image.network(awayLogo, height: 45, width: 45),
                              const Text(
                                "VS",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Image.network(homeLogo, height: 45, width: 45),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "$awayTeam vs $homeTeam",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$scheduled",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refreshing NBA games...')),
          );
          try {
            await apiService.refreshNBAGames();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('NBA games refreshed successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error refreshing games: $e')),
            );
          }
        },
      ),
    );
  }
}
