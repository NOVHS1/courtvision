import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_details_page.dart';

class PlayerComparePage extends StatefulWidget {
  const PlayerComparePage({super.key});

  @override
  State<PlayerComparePage> createState() => _PlayerComparePageState();
}

class _PlayerComparePageState extends State<PlayerComparePage> {
  Map<String, dynamic>? playerA;
  Map<String, dynamic>? playerB;

  Map<String, dynamic>? statsA;
  Map<String, dynamic>? statsB;

  bool isLoadingStats = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Player A sent from PlayerDetailsPage compare button
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args['player'] != null) {
      playerA ??= args['player'];
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Compare Players"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Overview"),
              Tab(text: "Stats"),
              Tab(text: "Game Log"),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildPlayerSelectors(),
            const Divider(height: 0),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOverviewTab(),
                  _buildStatsTab(),
                  _buildGameLogTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // PLAYER SELECTORS
  // =======================================================

  Widget _buildPlayerSelectors() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _playerCard(
              label: "Player A",
              player: playerA,
              onTap: () => _openPlayerSelector(isA: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _playerCard(
              label: "Player B",
              player: playerB,
              onTap: () => _openPlayerSelector(isA: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerCard({
    required String label,
    required Map<String, dynamic>? player,
    required VoidCallback onTap,
  }) {
    final img = _bestImage(player);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 115,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[800],
              backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
              child: img.isEmpty
                  ? const Icon(Icons.person, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player != null ? player['strPlayer'] : label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: player != null ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: player != null ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // PLAYER PICKER MODAL
  // =======================================================

  Future<void> _openPlayerSelector({required bool isA}) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _PlayerSearchSelector(),
    );

    if (selected != null) {
      setState(() {
        if (isA) {
          playerA = selected;
        } else {
          playerB = selected;
        }
      });

      _loadStats();
    }
  }

  // =======================================================
  // FETCH BOTH PLAYERS' STATS
  // =======================================================

  Future<void> _loadStats() async {
    if (playerA == null || playerB == null) return;

    setState(() => isLoadingStats = true);

    try {
      final a = await FirebaseFirestore.instance
          .collection('player_stats')
          .doc(playerA!['idPlayer'])
          .get();

      final b = await FirebaseFirestore.instance
          .collection('player_stats')
          .doc(playerB!['idPlayer'])
          .get();

      setState(() {
        statsA = a.data();
        statsB = b.data();
        isLoadingStats = false;
      });
    } catch (e) {
      print("Error loading stats: $e");
      setState(() => isLoadingStats = false);
    }
  }

  // =======================================================
  // TAB 1: OVERVIEW
  // =======================================================

  Widget _buildOverviewTab() {
    if (playerA == null || playerB == null) {
      return _placeholder("Select two players to compare.");
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _compareRow("Height", playerA!['strHeight'], playerB!['strHeight']),
          _compareRow("Weight", playerA!['strWeight'], playerB!['strWeight']),
          _compareRow("Position", playerA!['strPosition'], playerB!['strPosition']),
          _compareRow("Birthdate", playerA!['dateBorn'], playerB!['dateBorn']),
          _compareRow("Nationality",
              playerA!['strNationality'], playerB!['strNationality']),
        ],
      ),
    );
  }

  // =======================================================
  // TAB 2: STATS
  // =======================================================

  Widget _buildStatsTab() {
    if (statsA == null || statsB == null) {
      return _placeholder("Player stats not available.");
    }

    final a = statsA!['stats'] ?? [];
    final b = statsB!['stats'] ?? [];

    if (a.isEmpty || b.isEmpty) {
      return _placeholder("Not enough data to compare.");
    }

    final Map<String, dynamic> ga = a.first;
    final Map<String, dynamic> gb = b.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statCompareRow("PTS", ga['intPoints'], gb['intPoints']),
        _statCompareRow("REB", ga['intRebounds'], gb['intRebounds']),
        _statCompareRow("AST", ga['intAssists'], gb['intAssists']),
        _statCompareRow("STL", ga['intSteals'], gb['intSteals']),
        _statCompareRow("BLK", ga['intBlocks'], gb['intBlocks']),
        _statCompareRow("MIN", ga['intMinutes'], gb['intMinutes']),
      ],
    );
  }

  // =======================================================
  // TAB 3: GAME LOG
  // =======================================================

  Widget _buildGameLogTab() {
    if (statsA == null || statsB == null) {
      return _placeholder("No game logs available.");
    }

    final a = statsA!['stats'] ?? [];
    final b = statsB!['stats'] ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Last 5 Games",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _gameLogColumn(playerA!['strPlayer'], a),
        const SizedBox(height: 20),
        _gameLogColumn(playerB!['strPlayer'], b),
      ],
    );
  }

  // =======================================================
  // UI HELPERS
  // =======================================================

  Widget _placeholder(String t) => Center(
        child: Text(t, style: const TextStyle(color: Colors.white54)),
      );

  Widget _compareRow(String label, dynamic a, dynamic b) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a?.toString() ?? "N/A",
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              b?.toString() ?? "N/A",
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCompareRow(String label, dynamic a, dynamic b) {
    return _compareRow(label, a?.toString() ?? "-", b?.toString() ?? "-");
  }

  Widget _gameLogColumn(String title, List logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (final g in logs.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              "${g['dateEvent']} — ${g['intPoints']} pts, ${g['intRebounds']} reb, ${g['intAssists']} ast",
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
      ],
    );
  }

  String _bestImage(Map<String, dynamic>? p) {
    if (p == null) return "";

    final cut = p['strCutout'];
    final thumb = p['strThumb'];
    final render = p['strRender'];

    if (cut != null && cut.toString().isNotEmpty) return cut;
    if (thumb != null && thumb.toString().isNotEmpty) return thumb;
    if (render != null && render.toString().isNotEmpty) return render;

    return "";
  }
}

// =======================================================
// PLAYER SEARCH MODEL
// =======================================================

class _PlayerSearchSelector extends StatefulWidget {
  @override
  State<_PlayerSearchSelector> createState() =>
      _PlayerSearchSelectorState();
}

class _PlayerSearchSelectorState extends State<_PlayerSearchSelector> {
  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool isLoading = false;

  Future<void> _search(String name) async {
    if (name.trim().isEmpty) return;

    setState(() => isLoading = true);

    final snap = await FirebaseFirestore.instance
        .collection('nba_players')
        .where('strPlayer', isGreaterThanOrEqualTo: name)
        .where('strPlayer', isLessThanOrEqualTo: "$name\uf8ff")
        .get();

    results = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 70,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            const SizedBox(height: 14),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchCtrl,
                onSubmitted: _search,
                decoration: InputDecoration(
                  labelText: "Search Player",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[850],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final p = results[i];
                    final img = p['strThumb'] ?? "";

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            img.isNotEmpty ? NetworkImage(img) : null,
                        child: img.isEmpty
                            ? const Icon(Icons.person, color: Colors.white70)
                            : null,
                      ),
                      title: Text(p['strPlayer'] ?? "Unknown"),
                      subtitle: Text(p['strTeam'] ?? ""),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
