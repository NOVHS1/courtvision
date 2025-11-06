import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_service.dart';
import 'api_service.dart';

class PlayerStatsPage extends StatefulWidget {
  final String playerName;
  final String teamName;
  final String teamId;
  final String playerId;

  const PlayerStatsPage({
    super.key,
    required this.playerName,
    required this.teamName,
    required this.playerId,
    required this.teamId,
  });

  @override
  State<PlayerStatsPage> createState() => _PlayerStatsPageState();
}

class _PlayerStatsPageState extends State<PlayerStatsPage> {
  bool isLoading = true;
  Map<String, dynamic> stats = {};
  final PlayerService playerService = PlayerService();
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    loadPlayerStats();
  }

  //Try to load from Firestore first, else pull from SportsDB
  Future<void> loadPlayerStats() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('team_rosters')
          .doc(widget.teamId)
          .collection('players')
          .doc(widget.playerId)
          .get();

      if (doc.exists) {
        setState(() {
          stats = doc.data()!;
          isLoading = false;
        });
      } else {
        print("Player not found in Firestore — fetching from SportsDB...");

        //Fetch player info from SportsDB
        final data = await apiService.fetchPlayerDetails(widget.playerId);

        setState(() {
          stats = {
            "full_name": data['strPlayer'] ?? widget.playerName,
            "team": data['strTeam'] ?? widget.teamName,
            "position": data['strPosition'] ?? 'Unknown',
            "height": data['strHeight'] ?? 'N/A',
            "weight": data['strWeight'] ?? 'N/A',
            "points_per_game": 0,
            "assists_per_game": 0,
            "rebounds_per_game": 0,
            "photo": data['strThumb'] ??
                "https://cdn.nba.com/headshots/nba/latest/1040x760/${widget.playerId}.png",
          };
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading player stats: $e");
      setState(() => isLoading = false);
    }
  }

  //Update a player stat in Firestore
  Future<void> updatePlayerStat(String field, double newValue) async {
    await playerService.updatePlayer(widget.teamId, widget.playerId, {field: newValue});
    setState(() {
      stats[field] = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playerName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Home", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(stats['photo'] ??
                        "https://cdn.nba.com/headshots/nba/latest/1040x760/${widget.playerId}.png"),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    stats['full_name'] ?? widget.playerName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    stats['position'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Team: ${stats['team'] ?? widget.teamName}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Height: ${stats['height']} | Weight: ${stats['weight']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  const Divider(thickness: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.5,
                      children: [
                        editableStatTile("Points", "points_per_game"),
                        editableStatTile("Assists", "assists_per_game"),
                        editableStatTile("Rebounds", "rebounds_per_game"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('team_rosters')
                          .doc(widget.teamId)
                          .collection('players')
                          .doc(widget.playerId)
                          .delete();

                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Delete Player"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  //Editable stat tile widget
  Widget editableStatTile(String label, String field) {
    double value = (stats[field] ?? 0).toDouble();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  if (value > 0) updatePlayerStat(field, value - 0.5);
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  updatePlayerStat(field, value + 0.5);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
