import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'alert_service.dart';
import 'gesture_classifier.dart';
import 'voice_service.dart';

class EmergencyDetector {
  static final EmergencyDetector _instance = EmergencyDetector._internal();
  factory EmergencyDetector() => _instance;
  EmergencyDetector._internal();

  bool _isMonitoring = false;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<double>? _volumeSubscription;

  // To detect rapid clicks
  int _volumeClickCount = 0;
  DateTime? _lastVolumeClick;

  // To detect hold (many rapid events)
  int _volumeHoldScore = 0;
  DateTime? _lastHoldEvent;

  Future<void> startMonitoring({bool forceRestart = false}) async {
    if (_isMonitoring && !forceRestart) return;
    if (_isMonitoring && forceRestart) {
      debugPrint(
        "EmergencyDetector: Force-restarting monitoring in foreground...",
      );
      _accelSubscription?.cancel();
      _volumeSubscription?.cancel();
      _accelSubscription = null;
      _volumeSubscription = null;
      _isMonitoring = false;
    }
    _isMonitoring = true;
    debugPrint("EmergencyDetector: Starting Emergency Monitoring...");

    final prefs = await SharedPreferences.getInstance();

    // 1. Custom Shake Detection
    try {
      if (prefs.getBool('shake_enabled') ?? true) {
        double thresholdX = prefs.getDouble('shake_threshold_x') ?? 25.0;
        double thresholdY = prefs.getDouble('shake_threshold_y') ?? 25.0;
        double thresholdZ = prefs.getDouble('shake_threshold_z') ?? 25.0;

        _accelSubscription = accelerometerEventStream().listen((event) {
          if (event.x.abs() > thresholdX ||
              event.y.abs() > thresholdY ||
              event.z.abs() > thresholdZ) {
            debugPrint("EmergencyDetector: SHAKE DETECTED");
            AlertService().triggerAlert();
          }
        });
      }
    } catch (e) {
      debugPrint("EmergencyDetector: Shake Detection Error: $e");
    }

    // 2. Physical Button Triggers
    try {
      if (prefs.getBool('hold_button_enabled') ?? true) {
        String triggerType = prefs.getString('button_trigger_type') ?? 'volume';
        debugPrint(
          "EmergencyDetector: Initializing Button Trigger ($triggerType)...",
        );

        if (triggerType == 'volume') {
          // Setting hideUI to false can sometimes help background stream registration
          PerfectVolumeControl.hideUI = false;

          _volumeSubscription = PerfectVolumeControl.stream.listen((volume) {
            final now = DateTime.now();
            debugPrint("EmergencyDetector: Volume Event -> $volume");

            // Logic for rapid clicks (5 times)
            if (_lastVolumeClick == null ||
                now.difference(_lastVolumeClick!) <
                    const Duration(milliseconds: 1000)) {
              _volumeClickCount++;
            } else {
              _volumeClickCount = 1;
            }
            _lastVolumeClick = now;

            if (_volumeClickCount >= 5) {
              debugPrint(
                "🚨 EmergencyDetector: RAPID VOLUME PRESS DETECTED (5x)",
              );
              _volumeClickCount = 0;
              AlertService().triggerAlert();
            }

            // Logic for "hold" (rapid stream firing)
            if (_lastHoldEvent != null &&
                now.difference(_lastHoldEvent!) <
                    const Duration(milliseconds: 100)) {
              _volumeHoldScore++;
            } else {
              _volumeHoldScore = 0;
            }
            _lastHoldEvent = now;

            if (_volumeHoldScore >= 10) {
              debugPrint("🚨 EmergencyDetector: VOLUME BUTTON HOLD DETECTED");
              _volumeHoldScore = 0;
              AlertService().triggerAlert();
            }
          });
          debugPrint("EmergencyDetector: Volume listener attached.");
        } else if (triggerType == 'power') {
          debugPrint(
            "EmergencyDetector: Power button monitoring active via System SOS.",
          );
          // Note: Power button monitoring usually requires high-level system permissions
          // We recommend users enable "Emergency SOS" (5-press power) in Android Settings.
        }
      }
    } catch (e) {
      debugPrint("EmergencyDetector: Button Trigger Error: $e");
    }

    // 3. AI Gesture Detection (Legacy)
    try {
      GestureClassifier().init();
      GestureClassifier().start();
    } catch (e) {
      debugPrint("EmergencyDetector: Gesture Classifier Error: $e");
    }

    // 4. Voice Command
    try {
      if (prefs.getBool('voice_enabled') ?? true) {
        debugPrint("EmergencyDetector: Initializing Voice Service...");
        await VoiceService().init();
        await VoiceService().startListening();
        debugPrint("EmergencyDetector: Voice recognition requested.");
      }
    } catch (e) {
      debugPrint("EmergencyDetector: Voice Service Error: $e");
    }
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _volumeSubscription?.cancel();
    _accelSubscription = null;
    _volumeSubscription = null;
    VoiceService().stopListening();
    GestureClassifier().stop();
    _volumeClickCount = 0;
    _volumeHoldScore = 0;
    debugPrint("EmergencyDetector: Monitoring stopped.");
  }
}
