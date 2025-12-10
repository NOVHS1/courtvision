import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'player_details_page.dart';

class SearchPage extends StatefulWidget {
  final bool returnPlayer;
  const SearchPage({super.key, this.returnPlayer = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = false;
  List<dynamic> results = [];

  List<Map<String, dynamic>> cachedPlayers = [];     // 🔥 ADDED
  bool loadedInitialPlayers = false; 

  // ----------------------------------------
  // ALLOWED NBA TEAMS
  // ----------------------------------------
  static const nbaTeams = [
    "lakers", "clippers", "warriors", "kings", "suns",
    "bucks", "bulls", "celtics", "nets", "knicks",
    "heat", "magic", "hawks", "hornets", "cavaliers",
    "pistons", "pacers", "raptors", "76ers", "wizards",
    "nuggets", "timberwolves", "thunder", "blazers", "jazz",
    "mavericks", "spurs", "rockets", "pelicans", "grizzlies",
  ];

  // ----------------------------------------
  // BANNED SPORTS
  // ----------------------------------------
  static const bannedSports = [
    "soccer", "football", "baseball", "cricket", "rugby",
    "tennis", "hockey", "mma", "boxing", "golf",
    "volleyball", "handball", "cycling", "swimming",
    "table tennis", "darts", "snooker",
    "figure skating", "skiing", "snowboarding",
    "rowing", "sailing", "canoe", "kayak",
    "fencing", "archery", "shooting", "karate",
    "athletics", "gymnastics", "wrestling",
    "badminton", "lacrosse", "water polo",
    "equestrian", "surfing", "triathlon", "pentathlon",
    "curling", "bobsleigh", "luge", "skeleton", 
    "biathlon", "speed skating", "cross-country skiing", 
    "synchronized swimming", "rhythmic gymnastics",
  ];

  // ----------------------------------------
  // VALID NBA POSITIONS
  // ----------------------------------------
  static const nbaPositions = [
    "pg", "point guard",
    "sg", "shooting guard",
    "sf", "small forward",
    "pf", "power forward",
    "c", "center",
    "g", "f", "g-f", "f-g",
  ];

  // ----------------------------------------
  // FILTER FUNCTION
  // ----------------------------------------
  bool isNBAPlayer(Map<String, dynamic> p) {
    final team = (p['strTeam'] ?? "").toLowerCase();
    final desc = (p['strDescriptionEN'] ?? "").toLowerCase();
    final pos = (p['strPosition'] ?? "").toLowerCase();

    // Must match an NBA team OR be "_retired basketball"
    final validTeam =
        nbaTeams.any((t) => team.contains(t)) ||
        team.contains("_retired basketball");

    final retiredKeywords = [
      "retired basketball",
      "former nba",
      "ex-nba",
      "nba alumni",
      "_retired basketball",
    ];

    final isRetired = retiredKeywords.any((kw) => desc.contains(kw));

    final mentionedBasketball =
        desc.contains("nba") || desc.contains("basketball");

    if (!validTeam) return false;

    // Must NOT be from banned sports
    if (bannedSports.any((s) => desc.contains(s))) return false;

    // Must NOT be a coach/GM
    if (desc.contains("coach") ||
        desc.contains("manager") ||
        desc.contains("general manager")) return false;

    // Must have NBA-like position
    if (!nbaPositions.any((p) => pos.contains(p))) return false;

    return true;
  }

  // ----------------------------------------
  // SEARCH BY NAME
  // ----------------------------------------
  Future<void> searchPlayersByName(String name) async {
    if (name.isEmpty) return;

    setState(() => isLoading = true);

    try {
      // First try Firestore cache
      final snapshot = await FirebaseFirestore.instance
          .collection('nba_players')
          .where('strPlayer', isGreaterThanOrEqualTo: name)
          .where('strPlayer', isLessThanOrEqualTo: '$name\uf8ff')
          .get();

      final cached = snapshot.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .where((p) => isNBAPlayer(p))
          .toList();

      cachedPlayers = cached;
      loadedInitialPlayers = true; 

      if (cached.isNotEmpty) {
        setState(() => results = cached);
        return;
      }

      // No cache — search from API
      final apiResults = await apiService.searchNBAPlayers(name);

      if (apiResults.isNotEmpty) {
        final apiPlayer = apiResults.first;

      if (isNBAPlayer(apiPlayer)) {
         FirebaseFirestore.instance
        .collection('nba_players')
        .doc(apiPlayer['idPlayer'])
        .set(apiPlayer);

    setState(() => results = [apiPlayer]);
    return;
  }
}
      // Clean using filter
      final filtered = apiResults
          .where((p) => isNBAPlayer(p as Map<String, dynamic>))
          .toList();

      cachedPlayers = filtered.map((p) => p as Map<String, dynamic>).toList(); // 🔥 ADDED
      loadedInitialPlayers = true;
      
      setState(() => results = filtered);
    } catch (e) {
      print("Error searching players: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error searching players")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

    // --------------------------------------------------------
  // 🔥 NEW — Automatically filter results as the user types
  // --------------------------------------------------------
  void liveAutocomplete(String input) {     // 🔥 ADDED
    if (input.isEmpty) {
      setState(() => results = []);
      return;
    }

    // If initial load hasn't happened, run Firestore search
    if (!loadedInitialPlayers) {
      searchPlayersByName(input);
      return;
    }

    final filtered = cachedPlayers
        .where((p) =>
            p["strPlayer"].toString().toLowerCase().contains(input.toLowerCase()))
        .toList();

    setState(() => results = filtered);
  }

  // ----------------------------------------
  // LOAD ALL PLAYERS
  // ----------------------------------------
  Future<void> loadAllNBAPlayers({bool forceRefresh = false}) async {
    setState(() => isLoading = true);

    try {
      final allPlayers =
          await apiService.fetchAllNBAPlayers(forceRefresh: forceRefresh);

      final filtered = allPlayers
          .where((p) => isNBAPlayer(p as Map<String, dynamic>))
          .toList();

       cachedPlayers = filtered.map((p) => p as Map<String, dynamic>).toList(); // 🔥 ADDED
      loadedInitialPlayers = true; 

      setState(() => results = filtered);
    } catch (e) {
      print("Error loading all players: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load players")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ----------------------------------------
  // FAVORITES
  // ----------------------------------------
  Future<void> toggleFavorite(Map<String, dynamic> player) async {
    final favRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(player['idPlayer']);

    final doc = await favRef.get();

    if (doc.exists) {
      await favRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${player['strPlayer']} removed from favorites")),
      );
    } else {
      await favRef.set(player);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${player['strPlayer']} added to favorites")),
      );
    }

    setState(() {});
  }

  Future<bool> isFavorite(String playerId) async {
    return FirebaseFirestore.instance
        .collection('favorites')
        .doc(playerId)
        .get()
        .then((d) => d.exists);
  }

  // ----------------------------------------
  // UI
  // ----------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
         backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Search NBA Players", 
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 26,
        ),
      ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // SEARCH BAR
            TextField(
              controller: _searchController,
               onChanged: liveAutocomplete,
               style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search for an NBA player",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white12,
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      searchPlayersByName(_searchController.text.trim()),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) =>
                  searchPlayersByName(_searchController.text.trim()),
            ),

            const SizedBox(height: 15),

            // FAVORITES + LOAD ALL
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: openFavorites,
                    icon: const Icon(Icons.star, color: Colors.amber),
                    label: const Text("Favorites"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => loadAllNBAPlayers(),
                    icon: const Icon(Icons.people),
                    label: const Text("Load All Players"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // RESULTS
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? const Center(child: Text("No NBA players found."))
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final p = results[i];
                            final img = p['strCutout'];

                            return FutureBuilder<bool>(
                              future: isFavorite(p['idPlayer']),
                              builder: (context, snap) {
                                final fav = snap.data ?? false;

                                return Card(
                                  color: Colors.white10,          // 🔥 MATCH HOMEPAGE
                                  shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: img != null
                                          ? NetworkImage(img)
                                          : null,
                                      child: img == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    title: Text(p['strPlayer'] ?? ""),
                                    subtitle: Text(
                                      "${p['strTeam'] ?? ''} • ${p['strPosition'] ?? ''}",
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        fav ? Icons.star : Icons.star_border,
                                        color: fav ? Colors.amber : Colors.grey,
                                      ),
                                      onPressed: () => toggleFavorite(p),
                                    ),
                                    onTap: () {
                                      if (widget.returnPlayer){
                                        Navigator.pop(context, p);
                                          } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PlayerDetailsPage(
                                            playerId: p['idPlayer'],
                                            playerName: p['strPlayer'],
                                          ),
                                        ),
                                      );
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesPage()),
    );
  }
}

// ----------------------------------------------------
// FAVORITES PAGE
// ----------------------------------------------------
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream =
        FirebaseFirestore.instance.collection('favorites').snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("Favorite Players")),
      body: StreamBuilder(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No favorites yet"));
          }

          return ListView(
            children: docs.map((d) {
              final p = d.data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: p['strCutout'] != null
                      ? NetworkImage(p['strCutout'])
                      : null,
                ),
                title: Text(p['strPlayer'] ?? ""),
                subtitle: Text("${p['strTeam']} • ${p['strPosition']}"),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
