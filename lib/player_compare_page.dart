import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_page.dart';

class PlayerComparePage extends StatefulWidget {
  final Map<String, dynamic>? initialPlayer;

  const PlayerComparePage({super.key, this.initialPlayer});

  @override
  State<PlayerComparePage> createState() => _PlayerComparePageState();
}

class _PlayerComparePageState extends State<PlayerComparePage> {
  Map<String, dynamic>? playerA;
  Map<String, dynamic>? playerB;

  Map<String, dynamic>? statsA;
  Map<String, dynamic>? statsB;

  bool loadingStats = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlayer != null) {
      playerA = widget.initialPlayer;
    }
  }

  // -------------------------------------------------------------
  // LOAD STATS FOR BOTH PLAYERS
  // -------------------------------------------------------------
  Future<void> _loadStats() async {
    if (playerA == null || playerB == null) return;

    setState(() => loadingStats = true);

    final snapA = await FirebaseFirestore.instance
        .collection("player_stats")
        .doc(playerA!["id"] ?? playerA!["idPlayer"])
        .get();

    final snapB = await FirebaseFirestore.instance
        .collection("player_stats")
        .doc(playerB!["id"] ?? playerB!["idPlayer"])
        .get();

    setState(() {
      statsA = snapA.data();
      statsB = snapB.data();
      loadingStats = false;
    });
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Compare Players"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Season"),
              Tab(text: "Stats"),
              Tab(text: "Logs"),
            ],
          ),
        ),
        body: Column(
          children: [
            _playerSelectors(),
            const Divider(height: 0),
            Expanded(
              child: loadingStats
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _seasonTab(),
                        _singleGameStatsTab(),
                        _gameLogsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // PLAYER PICKER UI
  // -------------------------------------------------------------
  Widget _playerSelectors() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _playerTile(
              label: "Player A",
              player: playerA,
              onTap: () => _pickPlayer(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _playerTile(
              label: "Player B",
              player: playerB,
              onTap: () => _pickPlayer(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerTile({
    required String label,
    required Map<String, dynamic>? player,
    required VoidCallback onTap,
  }) {
    final img = player?["strThumb"] ?? "";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[900],
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[700],
              backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
              child: img.isEmpty
                  ? const Icon(Icons.person, size: 32, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player?["strPlayer"] ?? label,
                maxLines: 2,
                style: TextStyle(
                  fontSize: player != null ? 16 : 15,
                  color: player != null ? Colors.white : Colors.white54,
                  fontWeight:
                      player != null ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // PICK PLAYER FROM SEARCH PAGE
  // -------------------------------------------------------------
  Future<void> _pickPlayer(bool isA) async {
    final selected =
        await Navigator.pushNamed(context, "/search-player-select");

    if (selected is Map<String, dynamic>) {
      setState(() {
        if (isA) playerA = selected;
        else playerB = selected;
      });
      _loadStats();
    }
  }

  // -------------------------------------------------------------
  // TAB 1: SEASON AVERAGES
  // -------------------------------------------------------------
  Widget _seasonTab() {
    if (statsA == null || statsB == null) {
      return _emptyMessage("Select two players to compare.");
    }

    final a = statsA!["seasonAverages"] ?? {};
    final b = statsB!["seasonAverages"] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _compareRow("PPG", a["ppg"], b["ppg"]),
        _compareRow("RPG", a["rpg"], b["rpg"]),
        _compareRow("APG", a["apg"], b["apg"]),
        _compareRow("SPG", a["spg"], b["spg"]),
        _compareRow("BPG", a["bpg"], b["bpg"]),
        _compareRow("TOV", a["tov"], b["tov"]),
        _compareRow("FG%", a["fgPct"], b["fgPct"]),
        _compareRow("3P%", a["threePct"], b["threePct"]),
        _compareRow("FT%", a["ftPct"], b["ftPct"]),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 2: MOST RECENT GAME COMPARISON
  // -------------------------------------------------------------
  Widget _singleGameStatsTab() {
    if (statsA == null || statsB == null) {
      return _emptyMessage("Select two players to compare.");
    }

    final logsA = statsA!["gameLogs"] ?? [];
    final logsB = statsB!["gameLogs"] ?? [];

    if (logsA.isEmpty || logsB.isEmpty) {
      return _emptyMessage("Not enough game data to compare.");
    }

    final gA = logsA[0];
    final gB = logsB[0];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _compareRow("PTS", gA["pts"], gB["pts"]),
        _compareRow("REB", gA["reb"], gB["reb"]),
        _compareRow("AST", gA["ast"], gB["ast"]),
        _compareRow("STL", gA["stl"], gB["stl"]),
        _compareRow("BLK", gA["blk"], gB["blk"]),
        _compareRow("FG%", gA["fgPct"], gB["fgPct"]),
        _compareRow("3P%", gA["threePct"], gB["threePct"]),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: GAME LOGS
  // -------------------------------------------------------------
  Widget _gameLogsTab() {
    if (statsA == null || statsB == null) {
      return _emptyMessage("No game logs available.");
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Player A — Last 5 Games",
            style: TextStyle(fontWeight: FontWeight.bold)),
        _logsList(statsA!["gameLogs"]),
        const SizedBox(height: 20),
        const Text("Player B — Last 5 Games",
            style: TextStyle(fontWeight: FontWeight.bold)),
        _logsList(statsB!["gameLogs"]),
      ],
    );
  }

  Widget _logsList(List logs) {
    return Column(
      children: logs.map((g) {
        return ListTile(
          title: Text("${g['date']} — ${g['opponent']}"),
          subtitle: Text(
              "${g["pts"]} pts • ${g["reb"]} reb • ${g["ast"]} ast"),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------
  // HELPER WIDGETS
  // -------------------------------------------------------------
  Widget _emptyMessage(String msg) {
    return Center(
      child: Text(msg, style: const TextStyle(color: Colors.white54)),
    );
  }

  Widget _compareRow(String label, dynamic a, dynamic b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: Text(a?.toString() ?? "-"))),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Center(child: Text(b?.toString() ?? "-"))),
        ],
      ),
    );
  }
}
