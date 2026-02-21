import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:safestep/services/emergency_detector.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'database_helper.dart';

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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase background init error: $e");
  }

  // Initialize Hive for background isolate
  try {
    await DatabaseHelper.init();
  } catch (e) {
    debugPrint("Hive background init error: $e");
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

  service.on('refreshSettings').listen((event) {
    debugPrint("Background Isolate: Refreshing Settings...");
    EmergencyDetector().stopMonitoring();
    EmergencyDetector().startMonitoring();
  });

  // Start the Emergency Detector
  debugPrint("Background Isolate: Initializing Monitoring...");
  try {
    EmergencyDetector().startMonitoring();
    debugPrint("Background Isolate: Monitoring started successfully.");
  } catch (e) {
    debugPrint("Background Isolate Error during startMonitoring: $e");
  }

  // Keep alive logic if needed (Timer)
  // Note: isForegroundService() can throw exceptions in background isolates in some plugin versions
  /*
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
  */
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
