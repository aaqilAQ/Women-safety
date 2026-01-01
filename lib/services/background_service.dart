import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:safestep/services/emergency_detector.dart';
import 'package:firebase_core/firebase_core.dart';
// import '../firebase_options.dart'; // Uncomment after configuration

Future<void> initializeService() async {
  if (kIsWeb) return; // Background service is not supported on Web
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // User triggers it manually or via settings
      isForegroundMode: true,
      notificationChannelId: 'safestep_service',
      initialNotificationTitle: 'SafeStep Active',
      initialNotificationContent: 'Monitoring for emergencies...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  // Initialize Firebase for the background isolate
  try {
     // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); 
     await Firebase.initializeApp(); // Use default if configured or auto-configured
  } catch (e) {
    debugPrint("Firebase background init error: $e");
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Start the Emergency Detector
  EmergencyDetector().startMonitoring();
  
  // Keep alive logic if needed (Timer)
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "SafeStep Protected",
          content: "Monitoring active at ${DateTime.now()}",
        );
      }
    }
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
