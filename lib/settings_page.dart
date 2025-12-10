import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool darkMode = true;
  bool notificationsOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            value: notificationsOn,
            activeColor: Colors.blueAccent,
            title: const Text("Notifications"),
            onChanged: (v) => setState(() => notificationsOn = v),
          ),
          SwitchListTile(
            value: darkMode,
            activeColor: Colors.blueAccent,
            title: const Text("Dark Mode"),
            onChanged: (v) => setState(() => darkMode = v),
          ),
        ],
      ),
    );
  }
}
