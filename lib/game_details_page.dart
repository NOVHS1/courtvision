import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'player_details_page.dart';

class GameDetailsPage extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const GameDetailsPage({super.key, required this.gameData});

  @override
  State<GameDetailsPage> createState() => _GameDetailsPageState();
}

class _GameDetailsPageState extends State<GameDetailsPage> {
  List<Map<String, dynamic>> homeRoster = [];
  List<Map<String, dynamic>> awayRoster = [];

  Map<String, dynamic>? homeLeader;
  Map<String, dynamic>? awayLeader;

  bool isLoadingRosters = true;
  bool isLoadingLeaders = false;

  late String homeTeamFirestoreName;
  late String awayTeamFirestoreName;

  static const Map<String, String> triCodeToFirestoreName = {
    "ATL": "Atlanta Hawks", "BOS": "Boston Celtics", "BKN": "Brooklyn Nets",
    "CHA": "Charlotte Hornets", "CHI": "Chicago Bulls", "CLE": "Cleveland Cavaliers",
    "DAL": "Dallas Mavericks", "DEN": "Denver Nuggets", "DET": "Detroit Pistons",
    "GSW": "Golden State Warriors", "HOU": "Houston Rockets", "IND": "Indiana Pacers",
    "LAC": "LA Clippers", "LAL": "Los Angeles Lakers", "MEM": "Memphis Grizzlies",
    "MIA": "Miami Heat", "MIL": "Milwaukee Bucks", "MIN": "Minnesota Timberwolves",
    "NOP": "New Orleans Pelicans", "NYK": "New York Knicks", "OKC": "Oklahoma City Thunder",
    "ORL": "Orlando Magic", "PHI": "Philadelphia 76ers", "PHX": "Phoenix Suns",
    "POR": "Portland Trail Blazers", "SAC": "Sacramento Kings", "SAS": "San Antonio Spurs",
    "TOR": "Toronto Raptors", "UTA": "Utah Jazz", "WAS": "Washington Wizards",
  };

  @override
  void initState() {
    super.initState();

    final homeTri = widget.gameData["home"]["triCode"];
    final awayTri = widget.gameData["away"]["triCode"];

    //// ⭐ FIXED ⭐ use real team names instead of Null
    homeTeamFirestoreName =
        triCodeToFirestoreName[homeTri] ?? widget.gameData["home"]["name"];
    awayTeamFirestoreName =
        triCodeToFirestoreName[awayTri] ?? widget.gameData["away"]["name"];

    _loadRosters();
  }

  //// ⭐ FIXED ⭐ schedule uses scheduledEST (not scheduled)
  DateTime? _parseScheduled() {
    final est = widget.gameData['scheduledEST'];
    if (est == null) return null;

    try {
      return DateTime.parse(est).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRosters() async {
    setState(() => isLoadingRosters = true);

    try {
      final homeSnap = await FirebaseFirestore.instance
          .collection("nba_players")
          .where("strTeam", isEqualTo: homeTeamFirestoreName)
          .get();

      final awaySnap = await FirebaseFirestore.instance
          .collection("nba_players")
          .where("strTeam", isEqualTo: awayTeamFirestoreName)
          .get();

      homeRoster =
          homeSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      awayRoster =
          awaySnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

      setState(() => isLoadingRosters = false);

      _loadSeasonLeaders();
    } catch (e) {
      print("Roster error: $e");
      setState(() => isLoadingRosters = false);
    }
  }

  Future<void> _loadSeasonLeaders() async {
    setState(() => isLoadingLeaders = true);

    try {
      homeLeader = await _findLeader(homeRoster);
      awayLeader = await _findLeader(awayRoster);
    } catch (e) {
      print("Leader error: $e");
    }

    setState(() => isLoadingLeaders = false);
  }

  Future<Map<String, dynamic>?> _findLeader(
      List<Map<String, dynamic>> roster) async {
    double best = -1;
    Map<String, dynamic>? leader;

    for (final p in roster) {
      final id = p["idPlayer"];
      if (id == null) continue;

      final sDoc =
          await FirebaseFirestore.instance.collection("player_stats").doc(id).get();
      final s = sDoc.data()?["seasonAverages"];
      if (s == null) continue;

      final ppg = (s["ppg"] ?? 0).toDouble();

      if (ppg > best) {
        best = ppg;
        leader = {
          "player": p,
          "ppg": ppg,
          "rpg": (s["rpg"] ?? 0).toDouble(),
          "apg": (s["apg"] ?? 0).toDouble(),
        };
      }
    }

    return leader;
  }

  String _playerImg(Map<String, dynamic> p) {
    return p["strCutout"]?.toString().trim().isNotEmpty == true
        ? p["strCutout"]
        : p["strThumb"] ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _parseScheduled();

    //// ⭐ FIXED ⭐ no more TBD unless time missing
    final date = scheduled != null
        ? DateFormat("EEEE, MMM d • h:mm a").format(scheduled)
        : "Scheduled";

    final venue = widget.gameData["venue"];

    return Scaffold(
      appBar: AppBar(title: const Text("Game Details")),
      body: isLoadingRosters
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _header(date, venue),
                  const SizedBox(height: 20),
                  _buildSeasonLeaders(),
                  const SizedBox(height: 30),
                  _buildRosters(),
                ],
              ),
            ),
    );
  }

  // ---------------- HEADER ----------------
  Widget _header(String date, dynamic venue) {
    final homeTri = widget.gameData["home"]["triCode"];
    final awayTri = widget.gameData["away"]["triCode"];

    final homeScore = widget.gameData["home"]["score"].toString();
    final awayScore = widget.gameData["away"]["score"].toString();

    final rawStatus = (widget.gameData["status"] ?? "").toString();

    //// ⭐ FIXED ⭐ formats Final, Live, Q3, Halftime, Scheduled
    final displayStatus = _formatGameStatus(
      status: rawStatus,
      home: homeScore,
      away: awayScore,
      scheduled: date,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _teamLogo(awayTri),
            Column(
              children: [
                Text(
                  displayStatus,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            _teamLogo(homeTri),
          ],
        ),

        const SizedBox(height: 10),
        Text(date, style: const TextStyle(color: Colors.white70)),

        const SizedBox(height: 10),

        //// ⭐ FIXED ⭐ venue only shown if exists
        if (venue != null)
          Text(
            "${venue["name"]}, ${venue["city"]}",
            style: const TextStyle(color: Colors.white54),
          ),
      ],
    );
  }

  // ---------------- STATUS FORMATTER ----------------
  //// ⭐ FIXED ⭐ removes TBD and Null problems
  String _formatGameStatus({
    required String status,
    required String home,
    required String away,
    required String scheduled,
  }) {
    final s = status.toLowerCase();

    if (s.contains("final")) return "$away - $home";
    if (s.contains("in progress")) return status;
    if (s.contains("q")) return status;
    if (s.contains("halftime")) return "Halftime";
    if (s.contains("end")) return status;

    return scheduled;
  }

  // ---------------- BIGGER LOGOS ----------------
  Widget _teamLogo(String tri) {
    return Image.network(
      "https://a.espncdn.com/i/teamlogos/nba/500/$tri.png",
      height: 95,
      width: 95,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.error, size: 50, color: Colors.red),
    );
  }

  // ---------------- LEADERS ----------------
  Widget _buildSeasonLeaders() {
    if (isLoadingLeaders) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const Text("Season Leaders",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _leaderTile(awayLeader)),
            const SizedBox(width: 12),
            Expanded(child: _leaderTile(homeLeader)),
          ],
        ),
      ],
    );
  }

  Widget _leaderTile(Map<String, dynamic>? data) {
    if (data == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
        child: const Center(
            child: Text("No data", style: TextStyle(color: Colors.white54))),
      );
    }

    final p = data["player"];
    final img = _playerImg(p);
    final name = p["strPlayer"] ?? "Unknown";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${data['ppg']} PPG",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${data['rpg']} RPG",
                  style: const TextStyle(color: Colors.white70)),
              Text("${data['apg']} APG",
                  style: const TextStyle(color: Colors.white70)),
            ],
          )
        ],
      ),
    );
  }

  // ---------------- ROSTERS ----------------
  Widget _buildRosters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Rosters",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _rosterColumn(widget.gameData["away"]["name"], awayRoster)),
            const SizedBox(width: 12),
            Expanded(child: _rosterColumn(widget.gameData["home"]["name"], homeRoster)),
          ],
        ),
      ],
    );
  }

  Widget _rosterColumn(String title, List<Map<String, dynamic>> roster) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...roster.map(_rosterTile),
      ],
    );
  }

  Widget _rosterTile(Map<String, dynamic> p) {
    final img = _playerImg(p);
    final name = p["strPlayer"] ?? "Unknown";

    return GestureDetector(
      //// ⭐ FIXED ⭐ navigating to PlayerDetailsPage works
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PlayerDetailsPage(
                  playerId: p["idPlayer"], playerName: name)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(
              p["strNumber"] != null ? "#${p["strNumber"]}" : "",
              style: const TextStyle(color: Colors.white70),
            )
          ],
        ),
      ),
    );
  }
}
