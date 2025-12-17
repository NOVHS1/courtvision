import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'player_details_page.dart';

class FavoritePlayersPage extends StatelessWidget {
  const FavoritePlayersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

     if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050816),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text("Favorite Players"),
        ),
        body: const Center(
          child: Text(
            "Please log in to view favorites",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    
    final stream = FirebaseFirestore.instance
    .collection("favorites")
    .doc(user.uid)
    .collection("favorites")
    .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Favorite Players"),
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
              child: Text("No favorite players yet",
                  style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView(
            children: docs.map((d) {
              final p = d.data() as Map<String, dynamic>;
              return Card(
                color: Colors.white10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(p["strCutout"] ?? ""),
                  ),
                  title: Text(p["strPlayer"]),
                  subtitle: Text("${p["strTeam"]} • ${p["strPosition"]}",
                  style: const TextStyle(color: Colors.white70),
                  ),
                          onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerDetailsPage(
                          playerId: p["idPlayer"],
                          playerName: p["strPlayer"],
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
                  
