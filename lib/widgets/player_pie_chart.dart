import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PlayerPieChart extends StatelessWidget {
  final Map<String, double> data;
  final List<Color> colors;

  const PlayerPieChart({
    super.key,
    required this.data,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final values = data.values.toList();
    final labels = data.keys.toList();

    return SizedBox(
      height: 260,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: List.generate(values.length, (i) {
            return PieChartSectionData(
              color: colors[i],
              value: values[i],
              radius: 80,
              showTitle: true,
              title: "${labels[i]} (${values[i].toInt()}%)",
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            );
          }),
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }
}
