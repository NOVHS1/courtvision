import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PlayerComparisonBar extends StatelessWidget {
  final Map<String, dynamic> p1;
  final Map<String, dynamic> p2;

  const PlayerComparisonBar({
    super.key,
    required this.p1,
    required this.p2,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ["PPG", "RPG", "APG"];

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: _maxValue(p1, p2),
          barGroups: [
            _barGroup(0, p1["ppg"], p2["ppg"]),
            _barGroup(1, p1["rpg"], p2["rpg"]),
            _barGroup(2, p1["apg"], p2["apg"]),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  return Text(labels[index],
                      style: const TextStyle(color: Colors.white));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  double _maxValue(p1, p2) {
    final values = [
      p1["ppg"] ?? 0,
      p2["ppg"] ?? 0,
      p1["rpg"] ?? 0,
      p2["rpg"] ?? 0,
      p1["apg"] ?? 0,
      p2["apg"] ?? 0,
    ];
    return values.reduce((a, b) => a > b ? a : b).toDouble() + 5;
  }

  BarChartGroupData _barGroup(int index, num a, num b) {
    return BarChartGroupData(
      x: index,
      barsSpace: 12,
      barRods: [
        BarChartRodData(
          toY: a.toDouble(),
          color: Colors.blueAccent,
          width: 18, // thicker bars
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: b.toDouble(),
          color: Colors.redAccent,
          width: 18,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}