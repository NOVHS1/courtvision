import 'package:flutter/material.dart';
import 'api_service.dart';

class PlayerDetailsPage extends StatefulWidget {
  final String playerId;
  final String playerName;

  const PlayerDetailsPage({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<PlayerDetailsPage> createState() => _PlayerDetailsPageState();
}

class _PlayerDetailsPageState extends State<PlayerDetailsPage> {
  final ApiService apiService = ApiService();
  bool isLoading = true;
  Map<String, dynamic>? playerData;

  @override
  void initState() {
    super.initState();
    loadPlayerDetails();
  }

  Future<void> loadPlayerDetails() async {
    try {
      final details = await apiService.fetchPlayerDetails(widget.playerId);
      final stats = await apiService.getPlayerStats(widget.playerId);

      setState(() {
        playerData = {
          ...details,
          'stats': stats,
        };
        isLoading = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playerName),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : playerData == null
              ? const Center(child: Text("Player details not available"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundImage: playerData!['strCutout'] != null
                            ? NetworkImage(playerData!['strCutout'])
                            : null,
                        child: playerData!['strCutout'] == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      const SizedBox(height: 20),

                      Text(
                        playerData!['strPlayer'] ?? "Unknown Player",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "${playerData!['strTeam'] ?? 'Unknown Team'} • ${playerData!['strPosition'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 20),

                      infoRow("Nationality", playerData!['strNationality']),
                      infoRow("Height", playerData!['strHeight']),
                      infoRow("Weight", playerData!['strWeight']),
                      infoRow("Birth Date", playerData!['dateBorn']),
                      infoRow("Signing", playerData!['strSigning']),
                      const SizedBox(height: 20),

                      const Text(
                        "Biography",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        playerData!['strDescriptionEN'] ??
                            "No biography available.",
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 25),

                      // Player Stats Section
                      if (playerData!['stats'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Player Stats",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ...playerData!['stats']
                                .entries
                                .map<Widget>((entry) => infoRow(
                                      entry.key,
                                      entry.value.toString(),
                                    ))
                                .toList(),
                          ],
                        )
                      else
                        const Text("No stats available for this player."),
                    ],
                  ),
                ),
    );
  }

  Widget infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label:",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Flexible(
            child: Text(
              value?.isNotEmpty == true ? value! : "N/A",
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
