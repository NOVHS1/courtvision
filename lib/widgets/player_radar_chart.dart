import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PlayerRadarChart extends StatelessWidget {
  final Map<String, dynamic> p1;
  final Map<String, dynamic> p2;

  const PlayerRadarChart({super.key, required this.p1, required this.p2});

  static const List<String> labels = [
    "PPG",
    "RPG",
    "APG",
    "SPG",
    "BPG",
    "TOV",
    "FG%",
    "3P%",
    "FT%",
  ];

  List<RadarEntry> toRadar(Map<String, dynamic> stats) {
    double parse(dynamic v) =>
        v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);

    return [
      RadarEntry(value: parse(stats["ppg"])),
      RadarEntry(value: parse(stats["rpg"])),
      RadarEntry(value: parse(stats["apg"])),
      RadarEntry(value: parse(stats["spg"])),
      RadarEntry(value: parse(stats["bpg"])),
      RadarEntry(value: parse(stats["tov"]) * -1), // inverse for turnovers
      RadarEntry(value: parse(stats["fgPct"]) * 100),
      RadarEntry(value: parse(stats["threePct"]) * 100),
      RadarEntry(value: parse(stats["ftPct"]) * 100),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return RadarChart(
      RadarChartData(
        dataSets: [
          RadarDataSet(
            dataEntries: toRadar(p1),
            fillColor: Colors.blue.withOpacity(0.35),
            borderColor: Colors.blue,
            borderWidth: 2,
          ),
          RadarDataSet(
            dataEntries: toRadar(p2),
            fillColor: Colors.red.withOpacity(0.35),
            borderColor: Colors.red,
            borderWidth: 2,
          ),
        ],

        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),

        // Correct title function for older fl_chart versions
        getTitle: (index, angle) {
          return RadarChartTitle(
            text: labels[index],
          );
        },

        radarBorderData: const BorderSide(color: Colors.white24),
        tickBorderData: const BorderSide(color: Colors.white30),
        gridBorderData: const BorderSide(color: Colors.white24, width: 2),
      ),
    );
  }
}
