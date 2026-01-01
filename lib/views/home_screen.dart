import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this)..repeat(reverse: true);
    _checkServiceStatus();
  }

  void _checkServiceStatus() async {
    if (kIsWeb) return;
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (mounted) setState(() => _isServiceRunning = isRunning);
  }

  void _toggleService() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Background service not supported on Web")));
      return;
    }
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
    } else {
      service.startService();
    }
    setState(() => _isServiceRunning = !isRunning);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SafeStep"),
        actions: [
            IconButton(icon: const Icon(Icons.history), onPressed: () {}), // Logic later
            IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
            IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthService>().signOut()),
        ],
      ),
      body: Stack(
        children: [
           // Background gradient
           Container(
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 colors: [
                   Theme.of(context).colorScheme.surface,
                   Theme.of(context).colorScheme.surfaceVariant,
                 ],
               )
             ),
           ),
           Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               // Status Indicator
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                 decoration: BoxDecoration(
                   color: _isServiceRunning 
                       ? Colors.green.withValues(alpha: 0.1) 
                       : Colors.orange.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(30),
                   border: Border.all(
                       color: _isServiceRunning ? Colors.green : Colors.orange,
                       width: 2
                   )
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(Icons.shield, color: _isServiceRunning ? Colors.green : Colors.orange),
                     const SizedBox(width: 8),
                     Text(
                       _isServiceRunning ? "PROTECTED" : "PAUSED",
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         color: _isServiceRunning ? Colors.green : Colors.orange,
                         letterSpacing: 1.2
                       ),
                     ),
                   ],
                 ),
               ),
               
               const SizedBox(height: 60),
               
               // SOS Button
               GestureDetector(
                 onLongPress: () {
                    // Prevent accidental presses? Or single tap for test?
                    // Prompt says "Test Alert button". We can make it send logic.
                    // Real SOS usually requires a distinct action or slide.
                    AlertService().triggerAlert();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Test Alert Sent!")));
                 },
                 child: Stack(
                   alignment: Alignment.center,
                   children: [
                     // Ripple Effect
                     ScaleTransition(
                       scale: Tween(begin: 0.9, end: 1.1).animate(
                           CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
                       child: Container(
                         width: 220,
                         height: 220,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: Colors.red.withValues(alpha: 0.3),
                         ),
                       ),
                     ),
                     Container(
                       width: 180,
                       height: 180,
                       decoration: const BoxDecoration(
                         shape: BoxShape.circle,
                         gradient: LinearGradient(
                           colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         ),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black26, 
                             blurRadius: 15, 
                             offset: Offset(0, 10)
                           )
                         ]
                       ),
                       child: const Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.notifications_active, size: 48, color: Colors.white),
                           Text("SOS", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                           Text("HOLD TO ALERT", style: TextStyle(color: Colors.white70, fontSize: 12)),
                         ],
                       ),
                     ),
                   ],
                 ),
               ),

               const SizedBox(height: 60),

               // Quick Actions
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   _buildActionButton(context, Icons.contact_phone, "Contacts", () {
                     Navigator.pushNamed(context, '/contacts');
                   }),
                   _buildActionButton(context, _isServiceRunning ? Icons.stop : Icons.play_arrow, 
                       _isServiceRunning ? "Stop" : "Start", _toggleService),
                 ],
               )
             ],
           )
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(), 
            padding: const EdgeInsets.all(20),
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: Theme.of(context).primaryColor,
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
