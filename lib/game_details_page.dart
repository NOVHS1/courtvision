import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'player_details_page.dart';

class GameDetailsPage extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const GameDetailsPage({
    super.key,
    required this.gameData,
  });

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

  late String homeTeamName;
  late String awayTeamName;

  @override
  void initState() {
    super.initState();
    homeTeamName = _extractTeamName(isHome: true);
    awayTeamName = _extractTeamName(isHome: false);
    _loadRosters();
  }

  String _extractTeamName({required bool isHome}) {
    final game = widget.gameData;

    if (isHome) {
      if (game['home'] != null && game['home']['name'] != null) {
        return game['home']['name'];
      }
      if (game['home_team'] != null && game['home_team']['name'] != null) {
        return game['home_team']['name'];
      }
    } else {
      if (game['away'] != null && game['away']['name'] != null) {
        return game['away']['name'];
      }
      if (game['away_team'] != null && game['away_team']['name'] != null) {
        return game['away_team']['name'];
      }
    }

    return isHome ? 'Home Team' : 'Away Team';
  }

  DateTime? _parseScheduled() {
    final raw = widget.gameData['scheduled'];
    if (raw == null) return null;

    if (raw is Timestamp) return raw.toDate().toLocal();
    if (raw is String) {
      try {
        return DateTime.parse(raw).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _loadRosters() async {
    setState(() => isLoadingRosters = true);

    try {
      final homeFuture = FirebaseFirestore.instance
          .collection('nba_players')
          .where('strTeam', isEqualTo: homeTeamName)
          .get();

      final awayFuture = FirebaseFirestore.instance
          .collection('nba_players')
          .where('strTeam', isEqualTo: awayTeamName)
          .get();

      final results = await Future.wait([homeFuture, awayFuture]);

      homeRoster = results[0].docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
      awayRoster = results[1].docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      setState(() => isLoadingRosters = false);

      _loadSeasonLeaders();
    } catch (e) {
      print("Error loading rosters: $e");
      setState(() => isLoadingRosters = false);
    }
  }

  Future<void> _loadSeasonLeaders() async {
    setState(() => isLoadingLeaders = true);

    try {
      final results = await Future.wait([
        _computeLeaderForRoster(homeRoster),
        _computeLeaderForRoster(awayRoster),
      ]);

      homeLeader = results[0];
      awayLeader = results[1];

      setState(() => isLoadingLeaders = false);
    } catch (e) {
      print("Error loading leaders: $e");
      setState(() => isLoadingLeaders = false);
    }
  }

  Future<Map<String, dynamic>?> _computeLeaderForRoster(
      List<Map<String, dynamic>> roster) async {
    double highestPts = -1;
    Map<String, dynamic>? bestEntry;

    for (final player in roster) {
      final id = player['idPlayer'];
      if (id == null) continue;

      try {
        final doc = await FirebaseFirestore.instance
            .collection('player_stats')
            .doc(id)
            .get();

        if (!doc.exists) continue;

        final List<dynamic> stats = doc.data()?['stats'] ?? [];
        if (stats.isEmpty) continue;

        final last = stats.first;
        final pts = double.tryParse("${last['intPoints']}") ?? 0;

        if (pts > highestPts) {
          highestPts = pts;
          bestEntry = {
            'player': player,
            'points': pts,
            'lastGame': last,
          };
        }
      } catch (_) {}
    }

    return bestEntry;
  }

  String _bestPlayerImage(Map<String, dynamic> p) {
    final cutout = p['strCutout'];
    final thumb = p['strThumb'];

    if (cutout != null && "$cutout".isNotEmpty) return cutout;
    if (thumb != null && "$thumb".isNotEmpty) return thumb;

    return "";
  }

  String teamAlias(String name) {
    final map = {
      'los angeles lakers': 'lal',
      'golden state warriors': 'gsw',
      'boston celtics': 'bos',
      'miami heat': 'mia',
      'new york knicks': 'nyk',
      'brooklyn nets': 'bkn',
      'phoenix suns': 'phx',
      'chicago bulls': 'chi',
      'philadelphia 76ers': 'phi',
      'denver nuggets': 'den',
      'milwaukee bucks': 'mil',
      'memphis grizzlies': 'mem',
      'dallas mavericks': 'dal',
      'sacramento kings': 'sac',
      'cleveland cavaliers': 'cle',
      'new orleans pelicans': 'nop',
      'portland trail blazers': 'por',
      'minnesota timberwolves': 'min',
      'oklahoma city thunder': 'okc',
      'atlanta hawks': 'atl',
      'orlando magic': 'orl',
      'san antonio spurs': 'sas',
      'washington wizards': 'was',
      'toronto raptors': 'tor',
      'detroit pistons': 'det',
      'indiana pacers': 'ind',
      'utah jazz': 'uta',
      'charlotte hornets': 'cha',
      'houston rockets': 'hou',
      'los angeles clippers': 'lac',
    };

    return map[name.toLowerCase()] ??
        name.split(' ').last.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _parseScheduled();
    final date = scheduled != null
        ? DateFormat("EEEE, MMM d • h:mm a").format(scheduled)
        : "TBD";

    final venue = widget.gameData['venue'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Game Details"),
      ),
      body: isLoadingRosters
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildESPNHeader(date, venue),
                  const SizedBox(height: 20),
                  _buildSeasonLeaders(),
                  const SizedBox(height: 28),
                  _buildSideBySideRosters(),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------
  // ESPN HEADER
  // ---------------------------------------------------------
  Widget _buildESPNHeader(String date, Map<String, dynamic>? venue) {
    final homeAlias = teamAlias(homeTeamName);
    final awayAlias = teamAlias(awayTeamName);

    final status = widget.gameData['status'] ?? "scheduled";
    final homeScore = widget.gameData['home_points'] ?? "-";
    final awayScore = widget.gameData['away_points'] ?? "-";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.grey.shade900],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // LOGOS + SCORE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _teamLogo(awayAlias),
              Column(
                children: [
                  Text(
                    status == "closed"
                        ? "$awayScore - $homeScore"
                        : date,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == "closed"
                          ? Colors.green.withOpacity(.2)
                          : Colors.orange.withOpacity(.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == "closed"
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
              _teamLogo(homeAlias),
            ],
          ),

          const SizedBox(height: 20),

          // TEAM NAMES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                awayTeamName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                homeTeamName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // VENUE
          if (venue != null)
            Text(
              "${venue['name']} • ${venue['city']}, ${venue['state']}",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _teamLogo(String alias) {
    final url =
        "https://a.espncdn.com/i/teamlogos/nba/500/$alias.png";

    return Image.network(
      url,
      height: 70,
      width: 70,
      errorBuilder: (context, _, __) =>
          const Icon(Icons.broken_image, size: 50, color: Colors.white70),
    );
  }

  // ---------------------------------------------------------
  // SEASON LEADERS (ESPN STYLE)
  // ---------------------------------------------------------
  Widget _buildSeasonLeaders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Season Leaders",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        if (isLoadingLeaders)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(child: _leaderTile(homeLeader, homeTeamName)),
              const SizedBox(width: 12),
              Expanded(child: _leaderTile(awayLeader, awayTeamName)),
            ],
          ),
      ],
    );
  }

  Widget _leaderTile(Map<String, dynamic>? leader, String team) {
    if (leader == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "No leader data",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final p = leader['player'];
    final points = leader['points'];
    final img = _bestPlayerImage(p);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
            backgroundColor: Colors.grey[800],
            radius: 24,
            child:
                img.isEmpty ? const Icon(Icons.person, size: 28) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p['strPlayer'] ?? "Unknown",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Text(
            "${points.toString().replaceAll(".0", "")} PTS",
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // ROSTERS (ESPN SIDE-BY-SIDE)
  // ---------------------------------------------------------
  Widget _buildSideBySideRosters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Rosters",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _rosterColumn(awayTeamName, awayRoster),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _rosterColumn(homeTeamName, homeRoster),
            ),
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
        ...roster.map(_playerTile).toList(),
      ],
    );
  }

  Widget _playerTile(Map<String, dynamic> p) {
    final img = _bestPlayerImage(p);
    final name = p['strPlayer'] ?? "Unknown";
    final pos = p['strPosition'] ?? "";
    final num = p['strNumber'] ?? "";

    return GestureDetector(
      onTap: () {
        if (p['idPlayer'] == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PlayerDetailsPage(playerId: p['idPlayer'], playerName: name),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  img.isNotEmpty ? NetworkImage(img) : null,
              backgroundColor: Colors.grey[800],
              radius: 20,
              child: img.isEmpty
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              num.isNotEmpty ? "#$num" : "",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
