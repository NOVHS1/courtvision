import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_stats_page.dart';
import 'search_page.dart';
import 'game_details_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
        stream: FirebaseFirestore.instance.collection('nba_games').snapshots(),
        builder: (context, snapshot) {
          print("Connection state: ${snapshot.connectionState}");
          print("Has data: ${snapshot.hasData}");
          print("Document count: ${snapshot.data?.docs.length}");

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No games found in Firestore."));
          }

          final games = snapshot.data!.docs;

          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, index) {
              final gameData = games[index].data() as Map<String, dynamic>;

              final homeTeam = gameData['home']?['name'] ?? 'Unknown Home Team';
              final awayTeam = gameData['away']?['name'] ?? 'Unknown Away Team';
              final scheduled = gameData['scheduled'] ?? 'No time listed';
              final venue =
                  gameData['venue']?['location']?['name'] ?? 'Unknown Arena';

              return ListTile(
                title: Text('$awayTeam vs $homeTeam'),
                subtitle: Text('$scheduled • $venue'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameDetailsPage(gameData: gameData),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
