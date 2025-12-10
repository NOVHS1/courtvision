import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritePlayersPage extends StatelessWidget {
  const FavoritePlayersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance.collection("favorites").snapshots();

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
                  subtitle: Text("${p["strTeam"]} • ${p["strPosition"]}"),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
