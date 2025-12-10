import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:html/parser.dart' as html;

class BBRefTestPage extends StatefulWidget {
  const BBRefTestPage({super.key});

  @override
  State<BBRefTestPage> createState() => _BBRefTestPageState();
}

class _BBRefTestPageState extends State<BBRefTestPage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? result;
  bool loading = false;

  Future<void> runScraper() async {
    final code = _controller.text.trim().toLowerCase();
    if (code.isEmpty) return;

    setState(() {
      loading = true;
      result = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable("scrapeBBRefStats");

      final response = await callable.call({"playerCode": code});

      final data = response.data;

      setState(() => result = data);

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection("bbref_stats")
          .doc(code)
          .set(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved BBRef stats for $code")),
      );
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scraper failed: $e")),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "BBRef Scraper Test",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INPUT FIELD
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Enter BBRef Player Code",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // RUN BUTTON
            ElevatedButton(
              onPressed: loading ? null : runScraper,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Run Scraper",
                      style: TextStyle(fontSize: 18),
                    ),
            ),

            const SizedBox(height: 20),

            // RESULTS
            Expanded(
              child: result == null
                  ? const Center(
                      child: Text(
                        "Enter a code like 'jamesle01', 'duranke01', 'curryst01'",
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return ListView(
      children: [
        const Text(
          "Career Totals",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        ...((result?["career_totals"] ?? []) as List).map((season) {
          return Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Season: ${season["season"]}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text("Team: ${season["team"]}", style: const TextStyle(color: Colors.white70)),
                Text("Games: ${season["games"]}", style: const TextStyle(color: Colors.white70)),
                Text("Points: ${season["points"]}", style: const TextStyle(color: Colors.white70)),
                Text("Rebounds: ${season["rebounds"]}", style: const TextStyle(color: Colors.white70)),
                Text("Assists: ${season["assists"]}", style: const TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }),

        const SizedBox(height: 20),

        const Text(
          "Awards",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        Text(
          result?["awards"] ?? "No awards found.",
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
