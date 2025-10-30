import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameDetailsPage extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const GameDetailsPage({super.key, required this.gameData});

  @override
  State<GameDetailsPage> createState() => _GameDetailsPageState();
}

class _GameDetailsPageState extends State<GameDetailsPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> homePlayers = [];
  List<Map<String, dynamic>> awayPlayers = [];

  @override
  void initState() {
    super.initState();
    loadRosterData();
  }

  Future<void> loadRosterData() async {
    try {
      final homeTeamId = widget.gameData['home']?['reference'];
      final awayTeamId = widget.gameData['away']?['reference'];

      final homeSnapshot = await firestore
          .collection('team_rosters')
          .doc(homeTeamId)
          .collection('players')
          .get();

      final awaySnapshot = await firestore
          .collection('team_rosters')
          .doc(awayTeamId)
          .collection('players')
          .get();

      setState(() {
        homePlayers = homeSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        awayPlayers = awaySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print("Error loading rosters: $e");
      setState(() => isLoading = false);
    }
  }

  Widget buildPlayerTile(Map<String, dynamic> player) {
    final imageUrl = player['id'] != null
        ? "https://cdn.nba.com/headshots/nba/latest/260x190/${player['id']}.png"
        : "https://cdn-icons-png.flaticon.com/512/1077/1077012.png"; // fallback

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(imageUrl),
        backgroundColor: Colors.grey[300],
      ),
      title: Text(player['name'] ?? 'Unknown Player'),
      subtitle: Text(
        'Pos: ${player['position'] ?? 'N/A'}  |  '
        'PPG: ${player['points_per_game'] ?? 'N/A'}  |  '
        'REB: ${player['rebounds_per_game'] ?? 'N/A'}  |  '
        'AST: ${player['assists_per_game'] ?? 'N/A'}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeTeam = widget.gameData['home']?['name'] ?? 'Home';
    final awayTeam = widget.gameData['away']?['name'] ?? 'Away';

    return Scaffold(
      appBar: AppBar(title: Text('$awayTeam vs $homeTeam')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$homeTeam Roster',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  ...homePlayers.map(buildPlayerTile).toList(),

                  const SizedBox(height: 20),

                  Text(
                    '$awayTeam Roster',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  if (awayPlayers.isEmpty)
                    const Text("No roster found for away team."),
                  ...awayPlayers.map(buildPlayerTile).toList(),
                ],
              ),
            ),
    );
  }
}
