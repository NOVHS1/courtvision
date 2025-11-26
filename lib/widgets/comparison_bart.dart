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
      height: 220,
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < labels.length) {
                    return Text(labels[index], style: TextStyle(color: Colors.white));
                  }
                  return const Text("");
                },
              ),
            ),
          ),
          barGroups: [
            makeGroup(0, p1["ppg"], p2["ppg"]),
            makeGroup(1, p1["rpg"], p2["rpg"]),
            makeGroup(2, p1["apg"], p2["apg"]),
          ],
        ),
      ),
    );
  }

  BarChartGroupData makeGroup(int index, num a, num b) {
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(toY: a.toDouble(), color: Colors.blue, width: 8),
        BarChartRodData(toY: b.toDouble(), color: Colors.red, width: 8),
      ],
    );
  }
}
