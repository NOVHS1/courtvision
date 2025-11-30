import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  bool loading = true;
  Map<String, dynamic>? player;
  Map<String, dynamic>? stats;

  @override
  void initState() {
    super.initState();
    _loadPlayer();
  }

    Future<void> _loadPlayer() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("nba_players")
          .doc(widget.playerId)
          .get();

      final p = snap.data();

      final snapStats = await FirebaseFirestore.instance
          .collection("player_stats")
          .doc(widget.playerId)
          .get();

      final s = snapStats.data();

      setState(() {
        player = p;
        stats = s;          
        loading = false;
      });

    } catch (e) {
      print("Error loading player: $e");
      setState(() => loading = false);
    }
  }

  /// Format stats (double & percentages)
  String formatStat(dynamic value, {bool isPct = false}) {
    if (value == null) return "-";
    final num? parsed = num.tryParse(value.toString());
    if (parsed == null) return "-";
    if (isPct) return (parsed * 100).toStringAsFixed(1);
    return parsed.toStringAsFixed(1);
  }

  /// Pick NBA headshot > cutout > fallback cloud function
  String _bestImage(Map<String, dynamic> p) {
    final nbaId = p["nbaId"]?.toString() ?? "";
    if (nbaId.isNotEmpty) {
      return "https://cdn.nba.com/headshots/nba/latest/260x190/$nbaId.png";
    }

    final cut = p["strCutout"];
    final thumb = p["strThumb"];
    final render = p["strRender"];
    if (cut != null && cut.toString().isNotEmpty) return cut;
    if (thumb != null && thumb.toString().isNotEmpty) return thumb;
    if (render != null && render.toString().isNotEmpty) return render;

    final name = p["strPlayer"]?.toString() ?? "";
    if (name.isNotEmpty) {
      final encoded = Uri.encodeComponent(name);
      return "https://us-central1-courtvision-c400e.cloudfunctions.net/playerPhoto?name=$encoded";
    }

    return "https://cdn.nba.com/headshots/nba/latest/260x190/unknown.png";
  }

  String currentSeasonLabel() {
  final s = stats?["seasonAverages"];
  if (s != null && s["season"] != null) {
    return s["season"].toString(); 
  }
  final now = DateTime.now();
  final startYear = now.month >= 9 ? now.year : now.year - 1;
  final endYear = startYear + 1;
  return "$startYear-$endYear";
}

  String currentSeasonShort() {
  final now = DateTime.now();
  final start = now.month >= 9 ? now.year : now.year - 1;
  final end = start + 1;

  return "${start.toString().substring(2)}-${end.toString().substring(2)}";
}

  final Map<String, List<Color>> teamColors = {
    "los angeles lakers": [Color(0xFFFDB927), Color(0xFF552583)],
    "golden state warriors": [Color(0xFFFFC72C), Color(0xFF1D428A)],
    "boston celtics": [Color(0xFF007A33), Color(0xFFBA9653)],
    "miami heat": [Color(0xFF98002E), Color(0xFFF9A01B)],
    "brooklyn nets": [Color(0xFF000000), Color(0xFFFFFFFF)],
    "chicago bulls": [Color(0xFFCE1141), Color(0xFF000000)],
    "new york knicks": [Color(0xFF006BB6), Color(0xFFF58426)],
    "toronto raptors": [Color(0xFFCE1141), Color(0xFF000000)],
    "philadelphia 76ers": [Color(0xFF006BB6), Color(0xFFF5A31D)],
    "houston rockets": [Color(0xFFCE1141), Color(0xFF000000)],
    "dallas mavericks": [Color(0xFF00538C), Color(0xFFB8C4CA)],
    "san antonio spurs": [Color(0xFFC4CED4), Color(0xFF000000)],
    "portland trail blazers": [Color(0xFFE03A3E), Color(0xFF000000)],
    "oklahoma city thunder": [Color(0xFF007AC1), Color(0xFFEF3B24)],
    "utah jazz": [Color(0xFF002B5C), Color(0xFF00471B)],
    "denver nuggets": [Color(0xFFFEC524), Color(0xFF0E2240), Color(0xFF8B2131)],
    "washington wizards": [Color(0xFF002B5C), Color(0xFFC4CED4)],
    "cleveland cavaliers": [Color(0xFF6F263D), Color(0xFF041E42)],
    "atlanta hawks": [Color(0xFFC8102E), Color(0xFF26282A)],
    "indiana pacers": [Color(0xFF002D62), Color(0xFFFFB81C), Color(0xFFBEC0C2)],
    "orlando magic": [Color(0xFF0077C0), Color(0xFF000000)],
    "minnesota timberwolves": [Color(0xFF0C2340), Color(0xFF78BE20)],
    "sacramento kings": [Color(0xFF5A2D81), Color(0xFF63727A)],
    "new orleans pelicans": [Color(0xFF0C2340), Color(0xFFC8102E)],
    "milwaukee bucks": [Color(0xFF00471B), Color(0xFFFFB81C), Color(0xFFEEE1C6)],
    "detroit pistons": [Color(0xFFC8102E), Color(0xFF1D42BA)],
    "charlotte hornets": [Color(0xFF1D1160), Color(0xFF00788C)],
    "phoenix suns": [Color(0xFF1D1160), Color(0xFFFF7900)],
    "los angeles clippers": [Color(0xFFC8102E), Color(0xFF1D428A)],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playerName)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : player == null
              ? const Center(child: Text("Player not found"))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final team = (player!["strTeam"] ?? "").toLowerCase();
    final colors = teamColors[team] ?? [Colors.grey.shade700, Colors.black];

    return Column(
      children: [
        _buildHeader(colors),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: const [
                TabBar(
                  tabs: [
                    Tab(text: "Stats"),
                    Tab(text: "Game Log"),
                    Tab(text: "Bio"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      StatsTab(),
                      GameLogTab(),
                      BiographyTab(),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(List<Color> colors) {
    final p = player!;
    final name = p["strPlayer"] ?? "";
    final team = p["strTeam"] ?? "";
    final pos = p["strPosition"] ?? "";
    final num = p["strNumber"] ?? "";
    final img = _bestImage(p);

    final heightFt = p["strHeight"] ?? "-";
    double meters = 0;
    if (heightFt.contains("-")) {
      final parts = heightFt.split("-");
      final ft = int.tryParse(parts[0]) ?? 0;
      final in_ = int.tryParse(parts[1]) ?? 0;
      meters = (ft * 12 + in_) * 0.0254;
    }

    final weightLbs = p["strWeight"] ?? "-";
    double kg = 0;
    if (weightLbs.contains("lbs")) {
      final w = double.tryParse(weightLbs.replaceAll(" lbs", "")) ?? 0;
      kg = w / 2.205;
    }

    final birthdate = p["dateBorn"] ?? "-";
    int age = 0;
    if (birthdate != "-") {
      final dob = DateTime.tryParse(birthdate);
      if (dob != null) {
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
      }
    }

    final country = p["strNationality"] ?? "-";
    final draft = p["strDraft"] ?? "-";

    final bioTiles = [
      ["HEIGHT", "$heightFt (${meters.toStringAsFixed(2)} m)"],
      ["WEIGHT", "$weightLbs (${kg.toStringAsFixed(1)} kg)"],
      ["AGE", age.toString()],
      ["BORN", birthdate],
      ["COUNTRY", country],
      ["DRAFT", draft],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
              IconButton(
                icon: const Icon(Icons.compare_arrows),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/compare',
                  arguments: {'player': player},
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  img,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    "assets/images/default_player.png",
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    Text("$team • $pos", style: const TextStyle(color: Colors.white70)),
                    if (num.isNotEmpty)
                      Text("#$num", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bioTiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(bioTiles[i][0], style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      const SizedBox(width: 6),
                      Text(bioTiles[i][1], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
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

//
// ---------------------------
//       STATS TAB
// ---------------------------
//

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PlayerDetailsPageState>()!;
    final main = state.stats?["seasonAverages"];
    final proj = state.stats?["projections"];
    final all = state.stats?["allSeasonAverages"];

    if (main == null) return const Center(child: Text("No stats available."));

    List<Map<String, dynamic>> rows = [];

    if (proj != null) {
      rows.add({"label": "Projected", ...proj, "color": Colors.green.shade800});
    }

    rows.add({"label": state.currentSeasonLabel(), ...main, "color": Colors.grey.shade900});

    if (all != null && all is Map) {
      all.forEach((year, data) {
        if (data != null && year != state.currentSeasonLabel()) {
          rows.add({"label": year.toString(), ...data, "color": Colors.grey.shade800});
        }
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];

        List<String> labels = ["YEAR","PTS","REB","AST","STL","BLK","FG%","3P%","FT%","TOV"];
        List<dynamic> values = [
          row["label"],
          state.formatStat(row["ppg"]),
          state.formatStat(row["rpg"]),
          state.formatStat(row["apg"]),
          state.formatStat(row["spg"]),
          state.formatStat(row["bpg"]),
          state.formatStat(row["fgPct"], isPct: true),
          state.formatStat(row["threePct"], isPct: true),
          state.formatStat(row["ftPct"], isPct: true),
          state.formatStat(row["tov"]),
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: row["color"],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(children: labels.map((t) =>
                Expanded(child: Center(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12))))
              ).toList()),
              const SizedBox(height: 10),
              Row(children: values.map((v) =>
                Expanded(child: Center(child: Text("$v", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
              ).toList()),
            ],
          ),
        );
      },
    );
  }
}


//
// ---------------------------
//     GAME LOG TAB
// ---------------------------
//

class GameLogTab extends StatelessWidget {
  const GameLogTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PlayerDetailsPageState>()!;
    final logs = state.stats?["gameLogs"] ?? [];
    if (logs.isEmpty) return const Center(child: Text("No game logs available."));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final g = logs[i];
        return Card(
          color: Colors.grey[900],
          child: ListTile(
            title: Text("${g['date']} - ${g['opponent']}"),
            subtitle: Text("${g['pts']} pts • ${g['reb']} reb • ${g['ast']} ast"),
            trailing: Text(g['result']),
          ),
        );
      },
    );
  }
}

//
// ---------------------------
//         BIO TAB
// ---------------------------
//

class BiographyTab extends StatelessWidget {
  const BiographyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PlayerDetailsPageState>()!;
    final bio = state.player?["strDescriptionEN"] ?? "No biography available.";
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bio, style: const TextStyle(fontSize: 16, height: 1.4)),
      ],
    );
  }
}
