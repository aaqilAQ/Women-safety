import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shake/shake.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'alert_service.dart';

class EmergencyDetector {
  static final EmergencyDetector _instance = EmergencyDetector._internal();
  factory EmergencyDetector() => _instance;
  EmergencyDetector._internal();

  ShakeDetector? _shakeDetector;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  Timer? _voiceTimer;

  void startMonitoring() {
    debugPrint("Starting Emergency Monitoring...");
    
    // 1. Shake Detection
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        debugPrint("Shake detected!");
        AlertService().triggerAlert();
      },
      minimumShakeCount: 2,
      shakeSlopTimeMS: 500,
      shakeThresholdGravity: 2.7,
    );
    
    // 2. Voice Detection (Periodic listening to save battery or continuous)
    // Continuous listing in background is battery heavy and restricted on Android.
    // We will attempt to initialize it.
    _initSpeech();
  }

  void stopMonitoring() {
    _shakeDetector?.stopListening();
    _stopListening();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech Status: $status'),
      onError: (error) => debugPrint('Speech Error: $error'),
    );

    if (available) {
      // Listen periodically
      _voiceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
         if (!_isListening) {
           _listen();
         }
      });
    }
  }

  void _listen() async {
    if (_isListening) return;
    _isListening = true;
    
    await _speech.listen(
      onResult: (result) {
        String words = result.recognizedWords.toLowerCase();
        if (words.contains("help") || words.contains("sos") || words.contains("save me")) {
           AlertService().triggerAlert();
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
      localeId: "en_US", 
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        onDevice: true, // Forces offline recognition if available
      ),
    );
    
    // Reset listening state after a bit
    Future.delayed(const Duration(seconds: 6), () {
      _isListening = false;
    });
  }
  
  void _stopListening() {
    _voiceTimer?.cancel();
    _speech.stop();
  }
}
