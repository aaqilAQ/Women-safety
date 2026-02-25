import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'complaints_page.dart';
import 'voice_training_page.dart';
import 'shake_training_page.dart';
import '../services/voice_service.dart';
import '../services/emergency_detector.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  bool _isBackgroundActive = false;
  bool _isShakeEnabled = true;
  bool _isVoiceEnabled = true;
  bool _isHoldButtonEnabled = true;
  String _selectedButtonTrigger = 'volume'; // 'volume', 'power', or 'both'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBackgroundActive = prefs.getBool('background_service_active') ?? false;
      _isShakeEnabled = prefs.getBool('shake_enabled') ?? true;
      _isVoiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _isHoldButtonEnabled = prefs.getBool('hold_button_enabled') ?? true;
      _selectedButtonTrigger =
          prefs.getString('button_trigger_type') ?? 'volume';
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value); // Save FIRST, before anything reads it

    setState(() {
      if (key == 'background_service_active') _isBackgroundActive = value;
      if (key == 'shake_enabled') _isShakeEnabled = value;
      if (key == 'voice_enabled') _isVoiceEnabled = value;
      if (key == 'hold_button_enabled') _isHoldButtonEnabled = value;
    });

    // Handle voice toggle directly — do NOT restart EmergencyDetector
    // because that would re-read prefs and restart voice regardless
    if (key == 'voice_enabled') {
      if (value) {
        debugPrint('Config: Voice enabled — starting VoiceService');
        await VoiceService().init();
        await VoiceService().startListening();
      } else {
        debugPrint(
          'Config: Voice disabled — stopping VoiceService permanently',
        );
        VoiceService()
            .stopListening(); // sets _isActive = false, kills restart loop
      }
      // Notify background service to sync the setting
      if (!kIsWeb) FlutterBackgroundService().invoke('refreshSettings');
      return; // Don't do the full detector restart below for voice toggle
    }

    // For other settings (shake, buttons), restart the detector to pick up the change
    EmergencyDetector().stopMonitoring();
    await EmergencyDetector().startMonitoring();

    if (!kIsWeb) {
      FlutterBackgroundService().invoke('refreshSettings');
    }
  }

  void _openShakeTraining() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShakeTrainingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Settings & Triggers",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _buildHeader("General Settings"),
          _buildToggleCard(
            Icons.notifications_active_outlined,
            "Background Monitoring",
            "Keep SafeStep active even when the app is closed.",
            _isBackgroundActive,
            (val) => _saveSetting('background_service_active', val),
          ),

          const SizedBox(height: 24),
          _buildHeader("Emergency Triggers"),
          _buildTriggerCard(
            Icons.vibration,
            "Shake Detection",
            "Trigger alert by shaking your phone vigorously.",
            _isShakeEnabled,
            (val) => _saveSetting('shake_enabled', val),
            action: TextButton.icon(
              onPressed: _openShakeTraining,
              icon: const Icon(Icons.model_training, size: 18),
              label: const Text("Train Shake Pattern"),
            ),
          ),

          const SizedBox(height: 16),
          _buildTriggerCard(
            Icons.record_voice_over_outlined,
            "Voice Command",
            'Trigger alert by saying "Hey I need help".',
            _isVoiceEnabled,
            (val) => _saveSetting('voice_enabled', val),
            action: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VoiceTrainingPage(),
                  ),
                );
              },
              icon: const Icon(Icons.mic, size: 18),
              label: const Text("Setup Voice"),
            ),
          ),

          const SizedBox(height: 16),
          _buildTriggerCard(
            Icons.touch_app_outlined,
            "Physical Button Trigger",
            "Select which physical button you want to use for emergency alerts.",
            _isHoldButtonEnabled,
            (val) => _saveSetting('hold_button_enabled', val),
            action: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Choose Trigger Method:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'volume',
                        label: Text("Volume Key"),
                        icon: Icon(Icons.volume_up, size: 16),
                      ),
                      ButtonSegment(
                        value: 'power',
                        label: Text("Power Button"),
                        icon: Icon(Icons.power_settings_new, size: 16),
                      ),
                    ],
                    selected: {_selectedButtonTrigger},
                    onSelectionChanged: (Set<String> newSelection) async {
                      final val = newSelection.first;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('button_trigger_type', val);
                      setState(() => _selectedButtonTrigger = val);

                      if (!kIsWeb) {
                        FlutterBackgroundService().invoke('refreshSettings');
                      }
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: Colors.black,
                      selectedForegroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                if (_selectedButtonTrigger == 'power')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "Note: On most devices, pressing Power 5 times is the system's built-in SOS. SafeStep will monitor this if supported by your hardware.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (_selectedButtonTrigger == 'volume')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "Hold either Volume Up or Down vigorously to trigger SOS.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildHeader("Support"),
          _buildListTile(
            Icons.feedback_outlined,
            "Submit a Complaint",
            "Report issues or suggest improvements.",
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ComplaintsPage()),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildToggleCard(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.black),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.black,
      ),
    );
  }

  Widget _buildTriggerCard(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? Colors.black.withOpacity(0.02) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? Colors.black.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: value ? Colors.black : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.black,
              ),
            ],
          ),
          if (action != null) ...[
            const Divider(height: 24),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      tileColor: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withOpacity(0.05)),
      ),
    );
  }
}
