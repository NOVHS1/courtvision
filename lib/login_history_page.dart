import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginHistoryPage extends StatelessWidget {
  const LoginHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Login History"),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("logins")
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No recent logins",
                style: TextStyle(color: Colors.white70)));
          }

          return ListView(
            children: docs.map((e) {
              final ts = (e["timestamp"] as Timestamp).toDate();
              return ListTile(
                title: Text(
                  ts.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
