import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Shake Detection"),
            subtitle: const Text("Shake phone to trigger alert"),
            value: true, 
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text("Voice Detection"),
            subtitle: const Text("Listen for 'Help' or 'SOS'"),
            value: true, 
            onChanged: (val) {},
          ),
          const ListTile(
            title: Text("Shake Sensitivity"),
            subtitle: Text("Medium"),
          ),
        ],
      ),
    );
  }
}
