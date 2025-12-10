import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PlayerLineChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color color;

  const PlayerLineChart({
    super.key,
    required this.data,
    required this.labels,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < labels.length) {
                    return Text(
                      labels[index],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(data.length,
                  (i) => FlSpot(i.toDouble(), data[i].toDouble())),
              isCurved: true,
              barWidth: 3.5,
              color: color,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.2),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }
}