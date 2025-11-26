import 'package:flutter/material.dart';

class ShotEfficiencyStrip extends StatelessWidget {
  final Map<String, dynamic> p1;
  final Map<String, dynamic> p2;

  const ShotEfficiencyStrip({super.key, required this.p1, required this.p2});

  double _val(dynamic v) =>
      (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0);

  @override
  Widget build(BuildContext context) {
    final double rim1 = _val(p1["fgPct"]);      // You can refine layer later
    final double mid1 = _val(p1["threePct"]);   // placeholder mapping
    final double three1 = _val(p1["threePct"]);

    final double rim2 = _val(p2["fgPct"]);
    final double mid2 = _val(p2["threePct"]);
    final double three2 = _val(p2["threePct"]);

    return Column(
      children: [
        _strip("Player A", rim1, mid1, three1, Colors.blueAccent),
        const SizedBox(height: 6),
        _strip("Player B", rim2, mid2, three2, Colors.redAccent),
      ],
    );
  }

  Widget _strip(String name, double rim, double mid, double three, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$name", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            _zone("RIM", rim, color),
            _zone("MID", mid, color.withOpacity(0.85)),
            _zone("3PT", three, color.withOpacity(0.7)),
          ],
        ),
      ],
    );
  }

  Widget _zone(String label, double v, Color color) {
    return Expanded(
      child: Container(
        height: 25,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          "${(v * 100).toStringAsFixed(0)}%",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
