import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'settings_screen.dart';
import 'config_page.dart';
import 'profile_page.dart';
import 'contacts_detail_page.dart';
import 'contacts_screen.dart';
import 'complaints_page.dart';
import 'voice_training_page.dart';
import '../services/emergency_detector.dart';
import '../services/voice_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isServiceRunning = false;
  bool _isShakeEnabled = true;
  bool _isVoiceEnabled = true;
  bool _isHoldButtonEnabled = true;
  bool _isVoiceListening = false; // tracks live mic state
  UserModel? _cachedUser;

  StreamSubscription<bool>? _voiceSub;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _loadCachedUser();
    _loadUserName();
    _loadSettings();
    _startForegroundMonitoringIfEnabled();

    // Pulse animation for mic indicator
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Listen to VoiceService mic state
    _voiceSub = VoiceService().listeningStream.listen((isListening) {
      if (mounted) setState(() => _isVoiceListening = isListening);
    });
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('cached_user_name');
    if (cachedName != null && mounted) {
      setState(() {
        _cachedUser = UserModel(
          uid: '',
          name: cachedName,
          phone: '',
          emergencyContacts: [],
        );
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isShakeEnabled = prefs.getBool('shake_enabled') ?? true;
        _isVoiceEnabled = prefs.getBool('voice_enabled') ?? true;
        _isHoldButtonEnabled = prefs.getBool('hold_button_enabled') ?? true;
      });
    }
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await AuthService().getUser(user.uid);
      if (data != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_name', data.name);
        if (mounted) setState(() => _cachedUser = data);
      }
    }
  }

  void _startForegroundMonitoringIfEnabled() async {
    if (kIsWeb) return;
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      debugPrint("HomeScreen: Force-starting foreground monitoring...");
      await EmergencyDetector().startMonitoring(forceRestart: true);
    }
  }

  void _checkServiceStatus() async {
    if (kIsWeb) return;
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (mounted) setState(() => _isServiceRunning = isRunning);
    if (isRunning)
      await EmergencyDetector().startMonitoring(forceRestart: true);
  }

  void _toggleService() async {
    if (kIsWeb) return;

    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke("stopService");
      EmergencyDetector().stopMonitoring();
      if (mounted) setState(() => _isServiceRunning = false);
    } else {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.microphone,
        Permission.sms,
        Permission.notification,
      ].request();

      if (statuses[Permission.location]!.isGranted) {
        bool started = await service.startService();
        if (started) {
          // Give background service a moment to init, then override in foreground
          await Future.delayed(const Duration(milliseconds: 800));
          await EmergencyDetector().startMonitoring(forceRestart: true);
        }
        if (mounted) setState(() => _isServiceRunning = started);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location permission is required for protection"),
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Sign Out",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthService>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "SafeStep",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Colors.black87,
              size: 28,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8FAFC), Colors.white],
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildStatusCard(),
                  const SizedBox(height: 32),
                  _buildQuickConfig(),
                  const SizedBox(height: 40),
                  _buildEmergencyTip(),
                  const SizedBox(height: 100), // extra space for banner
                ],
              ),
            ),
          ),

          // ── Floating mic indicator ──────────────────────────────────
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: _isVoiceListening && _isServiceRunning
                  ? _buildListeningBanner()
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningBanner() {
    return Container(
      key: const ValueKey('mic_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.green.shade800,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade800.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing mic icon
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🎙️ Listening for your voice',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Say "help" to instantly trigger SOS',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          // Live dot indicator
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isServiceRunning ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isServiceRunning
              ? Colors.green.shade100
              : Colors.red.shade100,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _isServiceRunning
                ? Icons.verified_user_rounded
                : Icons.gpp_bad_rounded,
            size: 64,
            color: _isServiceRunning ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _isServiceRunning ? "Protection Active" : "Protection Offline",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isServiceRunning
                  ? Colors.green.shade900
                  : Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isServiceRunning
                ? "SafeStep is monitoring your safety in the background."
                : "Enable monitoring to start protection features.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isServiceRunning
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _toggleService,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isServiceRunning ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              _isServiceRunning ? "Stop Protection" : "Enable Protection",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Active Triggers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfigurationPage(),
                ),
              ).then((_) => _loadSettings()),
              child: const Text("Configure"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildTriggerChip(Icons.vibration, "Shake", _isShakeEnabled),
            _buildTriggerChip(Icons.mic, "Voice", _isVoiceEnabled),
            _buildTriggerChip(Icons.touch_app, "Buttons", _isHoldButtonEnabled),
          ],
        ),
      ],
    );
  }

  Widget _buildTriggerChip(IconData icon, String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: enabled
            ? Colors.black.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.black.withOpacity(0.1) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: enabled ? Colors.black : Colors.grey),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: enabled ? Colors.black : Colors.grey,
            ),
          ),
          if (enabled) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, size: 14, color: Colors.green),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyTip() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "Tip: In case of danger, say 'Hey I need help' or quickly shake your phone.",
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.black,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  _cachedUser?.name ?? "SafeStep User",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _cachedUser?.phone ?? "",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            Icons.contacts_outlined,
            "Contact Saving & Adding",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactsSetupScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(Icons.vibration, "Shake Training", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConfigurationPage(),
              ),
            );
          }),
          _buildDrawerItem(Icons.mic_none_rounded, "Voice Training", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VoiceTrainingPage(),
              ),
            );
          }),
          _buildDrawerItem(Icons.touch_app_outlined, "Button Press Config", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConfigurationPage(),
              ),
            );
          }),
          _buildDrawerItem(Icons.settings_outlined, "General Settings", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConfigurationPage(),
              ),
            ).then((_) => _loadSettings());
          }),
          _buildDrawerItem(
            Icons.report_problem_outlined,
            "Report Complaint",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ComplaintsPage()),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          _buildDrawerItem(
            Icons.logout_rounded,
            "Sign Out",
            _showLogoutDialog,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color ?? Colors.black87,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
