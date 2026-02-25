import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'alert_service.dart';
import 'gesture_classifier.dart';
import 'voice_service.dart';
import '../main.dart'; // Access global navigatorKey, messengerKey

class EmergencyDetector {
  static final EmergencyDetector _instance = EmergencyDetector._internal();
  factory EmergencyDetector() => _instance;
  EmergencyDetector._internal();

  bool _isMonitoring = false;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<double>? _volumeSubscription;

  // ── Volume rapid-click detection ──────────────────────────────────────────
  int _volumeClickCount = 0;
  DateTime? _lastVolumeClick;

  // ── Volume hold detection ─────────────────────────────────────────────────
  int _volumeHoldScore = 0;
  DateTime? _lastHoldEvent;

  // ── Cooldown: prevent accidental re-triggers ──────────────────────────────
  bool _buttonAlertCooldown = false;
  static const int _requiredRapidClicks = 7; // was 5 — stricter
  static const int _rapidClickWindowMs = 600; // was 1000ms — tighter
  static const int _requiredHoldScore = 20; // was 10 — stricter
  static const int _holdEventIntervalMs = 100;
  static const int _cooldownSeconds = 30; // cooldown between button triggers

  // ── Confirmation timer ────────────────────────────────────────────────────
  Timer? _confirmationTimer;
  bool _confirmationInProgress = false;

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
            _tryTriggerWithConfirmation('shake');
          }
        });
      }
    } catch (e) {
      debugPrint("EmergencyDetector: Shake Detection Error: $e");
    }

    // 2. Physical Button Triggers (HARDENED)
    try {
      if (prefs.getBool('hold_button_enabled') ?? true) {
        String triggerType = prefs.getString('button_trigger_type') ?? 'volume';
        debugPrint(
          "EmergencyDetector: Initializing Button Trigger ($triggerType)...",
        );

        if (triggerType == 'volume') {
          PerfectVolumeControl.hideUI = false;

          _volumeSubscription = PerfectVolumeControl.stream.listen((volume) {
            final now = DateTime.now();

            // ── Rapid-click detection (${ _requiredRapidClicks}× within ${_rapidClickWindowMs}ms) ──
            if (_lastVolumeClick == null ||
                now.difference(_lastVolumeClick!) <
                    const Duration(milliseconds: _rapidClickWindowMs)) {
              _volumeClickCount++;
            } else {
              _volumeClickCount = 1;
            }
            _lastVolumeClick = now;

            if (_volumeClickCount >= _requiredRapidClicks) {
              debugPrint(
                "🚨 EmergencyDetector: RAPID VOLUME PRESS DETECTED ($_requiredRapidClicks×)",
              );
              _volumeClickCount = 0;
              _tryTriggerWithConfirmation('rapid_volume_press');
            }

            // ── Hold detection (sustained press score >= $_requiredHoldScore) ──
            if (_lastHoldEvent != null &&
                now.difference(_lastHoldEvent!) <
                    const Duration(milliseconds: _holdEventIntervalMs)) {
              _volumeHoldScore++;
            } else {
              _volumeHoldScore = 0;
            }
            _lastHoldEvent = now;

            if (_volumeHoldScore >= _requiredHoldScore) {
              debugPrint("🚨 EmergencyDetector: VOLUME BUTTON HOLD DETECTED");
              _volumeHoldScore = 0;
              _tryTriggerWithConfirmation('volume_hold');
            }
          });
          debugPrint("EmergencyDetector: Volume listener attached.");
        } else if (triggerType == 'power') {
          debugPrint(
            "EmergencyDetector: Power button monitoring active via System SOS.",
          );
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

    // 4. Voice Command — STRICTLY check the preference before starting
    try {
      // Re-read the pref right now (it may have changed since startMonitoring was called)
      final freshPrefs = await SharedPreferences.getInstance();
      final voiceEnabled = freshPrefs.getBool('voice_enabled') ?? true;

      if (voiceEnabled) {
        debugPrint("EmergencyDetector: Initializing Voice Service...");
        await VoiceService().init();
        await VoiceService().startListening();
        debugPrint("EmergencyDetector: Voice recognition requested.");
      } else {
        // Explicitly ensure VoiceService is stopped
        debugPrint(
          "EmergencyDetector: voice_enabled=false → ensuring VoiceService is stopped.",
        );
        VoiceService().stopListening();
      }
    } catch (e) {
      debugPrint("EmergencyDetector: Voice Service Error: $e");
    }
  }

  /// Shows a 3-second confirmation countdown before triggering alert.
  /// If the user taps "Cancel" or the confirmation is already active, it won't re-trigger.
  void _tryTriggerWithConfirmation(String source) {
    if (_buttonAlertCooldown || _confirmationInProgress) {
      debugPrint(
        "EmergencyDetector: Button trigger ignored (cooldown=$_buttonAlertCooldown, confirming=$_confirmationInProgress).",
      );
      return;
    }

    _confirmationInProgress = true;

    debugPrint(
      "EmergencyDetector: Confirmation countdown started ($source). 3 seconds to cancel...",
    );

    // Try to show a cancellable snackbar in the UI
    bool cancelled = false;
    try {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text(
            "🚨 SOS TRIGGERING IN 3s — Tap CANCEL if accidental!",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'CANCEL',
            textColor: Colors.white,
            onPressed: () {
              cancelled = true;
              _confirmationTimer?.cancel();
              _confirmationInProgress = false;
              _volumeClickCount = 0;
              _volumeHoldScore = 0;
              debugPrint("EmergencyDetector: ❌ SOS cancelled by user.");
              messengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text("SOS cancelled."),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    } catch (_) {
      // UI not available (background/locked screen) — skip confirmation, trigger immediately
      debugPrint(
        "EmergencyDetector: No UI for confirmation — triggering immediately.",
      );
      _confirmationInProgress = false;
      _startCooldown();
      AlertService().triggerAlert();
      return;
    }

    // Countdown timer — trigger after 3 seconds if not cancelled
    _confirmationTimer = Timer(const Duration(seconds: 3), () {
      _confirmationInProgress = false;
      if (cancelled) return;

      debugPrint(
        "EmergencyDetector: ✅ Confirmation expired — TRIGGERING ALERT from $source.",
      );
      _startCooldown();
      AlertService().triggerAlert();
    });
  }

  void _startCooldown() {
    _buttonAlertCooldown = true;
    Future.delayed(Duration(seconds: _cooldownSeconds), () {
      _buttonAlertCooldown = false;
      debugPrint("EmergencyDetector: Button trigger cooldown expired.");
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _volumeSubscription?.cancel();
    _accelSubscription = null;
    _volumeSubscription = null;
    _confirmationTimer?.cancel();
    _confirmationInProgress = false;
    VoiceService().stopListening();
    GestureClassifier().stop();
    _volumeClickCount = 0;
    _volumeHoldScore = 0;
    debugPrint("EmergencyDetector: Monitoring stopped.");
  }
}
