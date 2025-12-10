import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // NEW — Automatically filter results as the user types
  // --------------------------------------------------------
  void liveAutocomplete(String input) {     
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

       cachedPlayers = filtered.map((p) => p as Map<String, dynamic>).toList(); 
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

    final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
    // 🔥 ADDED: Only authenticated users can save favorites
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You must be signed in to save favorites.")),
    );
    Navigator.pushNamed(context, '/auth');         
    return;
  }
  
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
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
        title: const Text(
          "Search Players",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --------------------------------------------
            // SEARCH BAR (MATCHES HOMEPAGE STYLE)
            // --------------------------------------------
            TextField(
              controller: _searchController,
              onChanged: liveAutocomplete,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search for an NBA player",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------
            // BUTTONS (UPGRADED UI)
            // --------------------------------------------
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => openFavorites(),
                    icon: const Icon(Icons.star, color: Colors.amber),
                    label: const Text("Favorites"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loadAllNBAPlayers,
                    icon: const Icon(Icons.people, color: Colors.white),
                    label: const Text("Load All Players"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --------------------------------------------
            // RESULTS
            // --------------------------------------------
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : results.isEmpty
                      ? const Center(
                          child: Text(
                            "No NBA players found",
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final p = results[i];
                            final img = p['strCutout'];

                            return FutureBuilder<bool>(
                              future: isFavorite(p['idPlayer']),
                              builder: (context, snap) {
                                final fav = snap.data ?? false;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          img != null ? NetworkImage(img) : null,
                                      child: img == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    title: Text(
                                      p['strPlayer'] ?? "",
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      "${p['strTeam'] ?? ''} • ${p['strPosition'] ?? ''}",
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        fav ? Icons.star : Icons.star_border,
                                        color: FirebaseAuth.instance.currentUser != null
                                            ? (fav ? Colors.amber : Colors.white54)
                                            : Colors.white24,
                                      ),
                                      onPressed: FirebaseAuth.instance.currentUser == null
                                          ? () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "You must be signed in to save favorites.",
                                                  ),
                                                ),
                                              );
                                              Navigator.pushNamed(context, '/auth');
                                          } : () => toggleFavorite(p),
                                    ),
                                    onTap: () {
                                      if (widget.returnPlayer) {
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

// FAVORITES PAGE (LIGHT STYLING)
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050816),
        appBar: AppBar(
          title: const Text("Favorites", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            "You must be signed in to view favorites.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        title: const Text("Favorites", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No favorites yet", style: TextStyle(color: Colors.white70)),
            );
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
                title: Text(
                  p['strPlayer'] ?? "",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  "${p['strTeam']} • ${p['strPosition']}",
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}