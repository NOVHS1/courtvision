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

  // 🔍 Search NBA players by name
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
        print("⚡ Found ${snapshot.docs.length} cached players for '$name'");
        setState(() => results = snapshot.docs.map((d) => d.data()).toList());
      } else {
        // If not cached, use API search
        final response = await apiService.searchNBAPlayers(name);
        setState(() => results = response);
      }
    } catch (e) {
      print("❌ Error searching players: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error searching players")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 🆕 Load All NBA Players (with caching)
  Future<void> loadAllNBAPlayers({bool forceRefresh = false}) async {
    setState(() => isLoading = true);
    try {
      final allPlayers =
          await apiService.fetchAllNBAPlayers(forceRefresh: forceRefresh);
      setState(() => results = allPlayers);
    } catch (e) {
      print("❌ Error fetching all NBA players: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load all NBA players")),
      );
    } finally {
      setState(() => isLoading = false);
    }
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

            // 🆕 Load All Players Button
            ElevatedButton.icon(
              onPressed: () => loadAllNBAPlayers(),
              icon: const Icon(Icons.people),
              label: const Text("Load All NBA Players"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),

            // 🆕 Force Refresh Button
            TextButton(
              onPressed: () => loadAllNBAPlayers(forceRefresh: true),
              child: const Text("Force Refresh from API",
                  style: TextStyle(color: Colors.redAccent)),
            ),

            const SizedBox(height: 20),

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
                        title: Text(playerName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text("$team • $position"),
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
