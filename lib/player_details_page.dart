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

  bool isLoading = true;
  Map<String, dynamic>? playerData;
  Map<String, dynamic>? statsData;

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    try {
      final detailsFuture = apiService.fetchPlayerDetails(widget.playerId);
      final statsFuture = apiService.getPlayerStats(widget.playerId);

      final results = await Future.wait([detailsFuture, statsFuture]);

      setState(() {
        playerData = results[0] as Map<String, dynamic>?;
        statsData = results[1] as Map<String, dynamic>?;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading player details: $e");
      setState(() => isLoading = false);
    }
  }

  String _stringField(String key, {String fallback = "N/A"}) {
    if (playerData == null) return fallback;
    final value = playerData![key];
    if (value == null || (value is String && value.trim().isEmpty)) {
      return fallback;
    }
    return value.toString();
  }

  /// Choose best available image
  String _bestPlayerImage(Map<String, dynamic> p) {
    final cutout = p['strCutout'];
    final thumb = p['strThumb'];
    final render = p['strRender'];

    if (cutout != null && cutout.toString().isNotEmpty) return cutout;
    if (thumb != null && thumb.toString().isNotEmpty) return thumb;
    if (render != null && render.toString().isNotEmpty) return render;

    if (p['strPlayer'] != null) {
      final name = p['strPlayer'].toString().toLowerCase().replaceAll(' ', '_');
      return "https://cdn.nba.com/headshots/nba/latest/260x190/$name.png";
    }

    return "https://a.espncdn.com/i/headshots/nba/players/full/0.png";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.playerName),
          centerTitle: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Bio"),
              Tab(text: "Stats"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : playerData == null
                ? const Center(child: Text("Player details not available"))
                : Column(
                    children: [
                      _buildHeader(context),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildBioTab(),
                            _buildStatsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // --------------------------
  // HEADER SECTION
  // --------------------------

  Widget _buildHeader(BuildContext context) {
    final name = _stringField('strPlayer', fallback: widget.playerName);
    final team = _stringField('strTeam', fallback: "Unknown Team");
    final position = _stringField('strPosition', fallback: "Position N/A");
    final jersey = _stringField('strNumber', fallback: "");

    final height = _stringField('strHeight');
    final weight = _stringField('strWeight');
    final birthDate = _stringField('dateBorn');
    final nationality = _stringField('strNationality');

    final imageUrl = _bestPlayerImage(playerData!);

    // TEAM COLORS
    final Map<String, List<Color>> teamColors = {
  "atlanta hawks": [Color(0xFFE03A3E), Color(0xFFFFC72C)],
  "boston celtics": [Color(0xFF007A33), Color(0xFFBA9653)],
  "brooklyn nets": [Color(0xFF000000), Color(0xFFFFFFFF)],
  "charlotte hornets": [Color(0xFF1D1160), Color(0xFF00788C)],
  "chicago bulls": [Color(0xFFCE1141), Color(0xFF000000)],
  "cleveland cavaliers": [Color(0xFF860038), Color(0xFF041E42)],
  "dallas mavericks": [Color(0xFF00538C), Color(0xFF002B5E)],
  "denver nuggets": [Color(0xFF0E2240), Color(0xFFFEC524)],
  "detroit pistons": [Color(0xFFC8102E), Color(0xFF006BB6)],
  "golden state warriors": [Color(0xFF1D428A), Color(0xFFFFC72C)],
  "houston rockets": [Color(0xFFCE1141), Color(0xFF000000)],
  "indiana pacers": [Color(0xFF002D62), Color(0xFFFDBB30)],
  "los angeles clippers": [Color(0xFFC8102E), Color(0xFF1D428A)],
  "los angeles lakers": [Color(0xFF552583), Color(0xFFFDB927)],
  "memphis grizzlies": [Color(0xFF5D76A9), Color(0xFF12173F)],
  "miami heat": [Color(0xFF98002E), Color(0xFFF9A01B)],
  "milwaukee bucks": [Color(0xFF00471B), Color(0xFFEEE1C6)],
  "minnesota timberwolves": [Color(0xFF0C2340), Color(0xFF236192)],
  "new orleans pelicans": [Color(0xFF0C2340), Color(0xFF85714D)],
  "new york knicks": [Color(0xFF006BB6), Color(0xFFF58426)],
  "oklahoma city thunder": [Color(0xFF007AC1), Color(0xFFEF3B24)],
  "orlando magic": [Color(0xFF0077C0), Color(0xFF000000)],
  "philadelphia 76ers": [Color(0xFFED174C), Color(0xFF006BB6)],
  "phoenix suns": [Color(0xFF1D1160), Color(0xFFE56020)],
  "portland trail blazers": [Color(0xFFD01C1F), Color(0xFF000000)],
  "sacramento kings": [Color(0xFF5A2D81), Color(0xFF63727A)],
  "san antonio spurs": [Color(0xFF000000), Color(0xFFC4CED4)],
  "toronto raptors": [Color(0xFFCE1141), Color(0xFF000000)],
  "utah jazz": [Color(0xFF002B5C), Color(0xFF00471B)],
  "washington wizards": [Color(0xFF002B5C), Color(0xFFE31837)],
};

    final key = team.toLowerCase();
    final gradientColors =
        teamColors[key] ?? [Colors.grey.shade800, Colors.grey.shade900];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 120,
              height: 120,
              color: Colors.black26,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.network(
                  "https://a.espncdn.com/i/headshots/nba/players/full/0.png",
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // NAME + TILES + BUTTONS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & jersey
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (jersey.isNotEmpty)
                                Text(
                                  "#$jersey",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("$team • $position",
                              style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),

                    // FAVORITE BUTTON
                    IconButton(
                      icon: const Icon(Icons.star_border, color: Colors.white),
                      onPressed: () async {
                        final favRef = FirebaseFirestore.instance
                            .collection('favorites')
                            .doc(playerData!['idPlayer']);

                        final doc = await favRef.get();
                        if (doc.exists) {
                          await favRef.delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("$name removed from favorites")),
                          );
                        } else {
                          await favRef.set(playerData!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("$name added to favorites")),
                          );
                        }
                        setState(() {});
                      },
                    ),

                    // COMPARE BUTTON
                    IconButton(
                      icon: const Icon(Icons.compare_arrows,
                          color: Colors.white),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/compare',
                          arguments: {'player1': playerData!},
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // PLAYER INFO TILES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoTile(label: "Height", value: height),
                    _infoTile(label: "Weight", value: weight),
                    _infoTile(label: "Born", value: birthDate),
                    _infoTile(label: "Country", value: nationality),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({required String label, required String value}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.isEmpty ? "N/A" : value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------
  // BIO TAB
  // --------------------------

  Widget _buildBioTab() {
    final bio =
        _stringField('strDescriptionEN', fallback: "No biography available.");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        bio,
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
    );
  }

  // --------------------------
  // STATS TAB
  // --------------------------

  Widget _buildStatsTab() {
    if (statsData == null) {
      return const Center(child: Text("No stats available."));
    }

    final List<dynamic> statLines = statsData!['stats'] ?? [];

    if (statLines.isEmpty) {
      return const Center(child: Text("No stats available."));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: statLines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = statLines[index];

        return Card(
          color: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['dateEvent'] ?? "",
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  s['strEvent'] ??
                      "${s['strAwayTeam']} @ ${s['strHomeTeam']}",
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statChip("MIN", s['intMinutes']),
                    _statChip("PTS", s['intPoints']),
                    _statChip("REB", s['intRebounds']),
                    _statChip("AST", s['intAssists']),
                    _statChip("STL", s['intSteals']),
                    _statChip("BLK", s['intBlocks']),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statChip(String label, dynamic value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          (value ?? "-").toString(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
