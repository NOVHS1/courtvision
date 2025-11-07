import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'player_details_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = false;
  List<dynamic> results = [];

  // Search NBA players by name (kept your original working logic)
  Future<void> searchPlayersByName(String name) async {
    if (name.isEmpty) return;

    setState(() => isLoading = true);
    try {
      // First, check Firestore cache
      final snapshot = await FirebaseFirestore.instance
          .collection('nba_players')
          .where('strPlayer', isGreaterThanOrEqualTo: name)
          .where('strPlayer', isLessThanOrEqualTo: '$name\uf8ff')
          .get();

      if (snapshot.docs.isNotEmpty) {
        print("Found ${snapshot.docs.length} cached players for '$name'");
        setState(() => results = snapshot.docs.map((d) => d.data()).toList());
      } else {
        // If not cached, use API search
        final response = await apiService.searchNBAPlayers(name);
        setState(() => results = response);
      }
    } catch (e) {
      print("Error searching players: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error searching players")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Load All NBA Players (with caching)
  Future<void> loadAllNBAPlayers({bool forceRefresh = false}) async {
    setState(() => isLoading = true);
    try {
      final allPlayers =
          await apiService.fetchAllNBAPlayers(forceRefresh: forceRefresh);
      setState(() => results = allPlayers);
    } catch (e) {
      print("Error fetching all NBA players: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load all NBA players")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Toggle favorite player
  Future<void> toggleFavorite(Map<String, dynamic> player) async {
    final favRef =
        FirebaseFirestore.instance.collection('favorites').doc(player['idPlayer']);
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
    setState(() {}); // refresh icons
  }

  Future<bool> isFavorite(String playerId) async {
    final doc =
        await FirebaseFirestore.instance.collection('favorites').doc(playerId).get();
    return doc.exists;
  }

  // Open Favorites Page
  void openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesPage()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search NBA Players"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Home", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔍 Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search for an NBA player",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      searchPlayersByName(_searchController.text.trim()),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) =>
                  searchPlayersByName(_searchController.text.trim()),
            ),

            const SizedBox(height: 15),

            // Favorites + Load All Players Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Favorites Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: openFavorites,
                    icon: const Icon(Icons.star, color: Colors.amber),
                    label: const Text("Favorites"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[850],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Load All Players Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => loadAllNBAPlayers(),
                    icon: const Icon(Icons.people),
                    label: const Text("Load All NBA Players"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Force Refresh
            TextButton(
              onPressed: () => loadAllNBAPlayers(forceRefresh: true),
              child: const Text(
                "Force Refresh from API",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),

            const SizedBox(height: 20),

            // Results Section
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (results.isEmpty)
              const Expanded(
                child: Center(child: Text("No NBA players found")),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final player = results[index];

                    final playerName = player['strPlayer'] ?? 'Unknown Player';
                    final position = player['strPosition'] ?? 'N/A';
                    final team = player['strTeam'] ?? 'Unknown';
                    final playerId = player['idPlayer'] ?? '';
                    final imageUrl = player['strCutout'];

                    return FutureBuilder<bool>(
                      future: isFavorite(playerId),
                      builder: (context, snapshot) {
                        final fav = snapshot.data ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: imageUrl != null
                                  ? NetworkImage(imageUrl)
                                  : null,
                              backgroundColor: Colors.grey[300],
                              child: imageUrl == null
                                  ? const Icon(Icons.person, color: Colors.black54)
                                  : null,
                            ),
                            title: Text(
                              playerName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text("$team • $position"),
                            trailing: IconButton(
                              icon: Icon(
                                fav ? Icons.star : Icons.star_border,
                                color: fav ? Colors.amber : Colors.grey,
                              ),
                              onPressed: () => toggleFavorite(player),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerDetailsPage(
                                    playerId: playerId,
                                    playerName: playerName,
                                  ),
                                ),
                              );
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
}

// Favorites Page
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesStream =
        FirebaseFirestore.instance.collection('favorites').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Favorite Players"),
      ),
      body: StreamBuilder(
        stream: favoritesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No favorite players yet"));
          }

          return ListView(
            children: docs.map((doc) {
              final player = doc.data() as Map<String, dynamic>;
              final playerName = player['strPlayer'] ?? 'Unknown';
              final team = player['strTeam'] ?? 'Unknown';
              final position = player['strPosition'] ?? '';
              final imageUrl = player['strCutout'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        imageUrl != null ? NetworkImage(imageUrl) : null,
                    child: imageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(playerName),
                  subtitle: Text("$team • $position"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('favorites')
                          .doc(player['idPlayer'])
                          .delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${player['strPlayer']} removed")),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
