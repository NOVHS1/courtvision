import 'package:flutter/material.dart';

class PlayerStatsPage extends StatefulWidget {
  final String playerName;
  final String teamName;
  final String playerId;

  const PlayerStatsPage({
    super.key,
    required this.playerName,
    required this.teamName,
    required this.playerId,
  });

  @override
  State<PlayerStatsPage> createState() => _PlayerStatsPageState();
}

class _PlayerStatsPageState extends State<PlayerStatsPage> {
  bool isLoading = true;
  Map<String, dynamic> stats = {};

  @override
  void initState() {
    super.initState();
    loadPlayerStats();
  }

  Future<void> loadPlayerStats() async {
    // 🔧 Replace this with your Firebase Cloud Function or API call later
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      stats = {
        "points": 27.4,
        "assists": 6.1,
        "rebounds": 7.3,
        "fg_pct": 0.498,
        "three_pct": 0.377,
        "ft_pct": 0.832,
        "games_played": 74,
      };
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playerName),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
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
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(
                      "https://cdn.nba.com/headshots/nba/latest/1040x760/${widget.playerId}.png",
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.teamName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
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
                        statTile("Points", stats["points"]),
                        statTile("Assists", stats["assists"]),
                        statTile("Rebounds", stats["rebounds"]),
                        statTile(
                          "FG%",
                          (stats["fg_pct"] * 100).toStringAsFixed(1),
                        ),
                        statTile(
                          "3PT%",
                          (stats["three_pct"] * 100).toStringAsFixed(1),
                        ),
                        statTile(
                          "FT%",
                          (stats["ft_pct"] * 100).toStringAsFixed(1),
                        ),
                        statTile("Games", stats["games_played"]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget statTile(String label, dynamic value) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            "$value",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
