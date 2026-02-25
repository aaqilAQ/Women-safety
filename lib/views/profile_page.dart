import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/sms_service.dart';
import '../models/user_model.dart';
import '../services/emergency_detector.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Map<String, dynamic>> _simCards = [];
  int? _selectedSubId;

  @override
  void initState() {
    super.initState();

    _loadSimCards();
  }

  Future<void> _loadSimCards() async {
    // Request permission if not granted
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
    }

    if (status.isGranted) {
      final sims = await SmsService().getSimCards();
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _simCards = sims;
        _selectedSubId = prefs.getInt('preferred_sim_id');
      });
    }
  }

  Future<void> _selectSim(int subId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('preferred_sim_id', subId);
    setState(() {
      _selectedSubId = subId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile"), centerTitle: true),
      body: FutureBuilder<UserModel?>(
        future: user != null ? authService.getUser(user.uid) : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Color(0xFFE0F7FA),
                  child: Icon(Icons.person, size: 60, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 30),
              _buildInfoTile(
                "Name",
                userData?.name ?? "N/A",
                Icons.person_outline,
              ),
              _buildInfoTile(
                "Phone",
                userData?.phone ?? "N/A",
                Icons.phone_outlined,
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "SOS SIM Settings",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadSimCards,
                    tooltip: "Refresh SIM List",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_simCards.isEmpty)
                const Text(
                  "No SIM cards detected or permission missing.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )
              else
                ..._simCards.map(
                  (sim) => RadioListTile<int>(
                    title: Text(sim['name'] ?? 'SIM'),
                    subtitle: Text("${sim['carrier']} (${sim['number']})"),
                    value: sim['id'],
                    groupValue: _selectedSubId,
                    onChanged: (val) {
                      if (val != null) _selectSim(val);
                    },
                  ),
                ),

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  EmergencyDetector().stopMonitoring();
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "Sign Out",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.blueGrey),
          title: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          subtitle: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
