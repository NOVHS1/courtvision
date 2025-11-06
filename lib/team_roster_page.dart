import 'package:flutter/material.dart';
import 'api_service.dart';

class TeamRosterPage extends StatefulWidget {
  final String teamName;

  const TeamRosterPage({super.key, required this.teamName});

  @override
  State<TeamRosterPage> createState() => _TeamRosterPageState();
}

class _TeamRosterPageState extends State<TeamRosterPage> {
  final ApiService apiService = ApiService();
  bool isLoading = true;
  List<dynamic> players = [];

  @override
  void initState() {
    super.initState();
    loadRoster();
  }

  Future<void> loadRoster() async {
    try {
      final data = await apiService.fetchTeamRoster(widget.teamName);
      setState(() {
        players = data;
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
      appBar: AppBar(title: Text("${widget.teamName} Roster")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : players.isEmpty
              ? const Center(child: Text("No players found"))
              : ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: player['strCutout'] != null
                            ? NetworkImage(player['strCutout'])
                            : null,
                        child: player['strCutout'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(player['strPlayer'] ?? "Unknown Player"),
                      subtitle: Text(player['strPosition'] ?? "Position N/A"),
                    );
                  },
                ),
    );
  }
}
