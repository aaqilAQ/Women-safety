import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'alert_service.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isActive = false;
  bool _isListening = false;
  bool _isInitialized = false;

  List<String> _triggers = ['help', 'sos', 'emergency'];
  Timer? _restartTimer;
  bool _alertInProgress = false;

  /// Whether voice is currently active (user intent = ON)
  bool get isActive => _isActive;

  // ── Public stream: UI listens to this to know mic state ──────────────────
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();
  Stream<bool> get listeningStream => _listeningController.stream;

  // ─── Public API ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadTriggers();
    await _initEngine();
  }

  Future<void> startListening() async {
    _isActive = true;

    if (!_isInitialized) {
      await _initEngine();
    }

    if (!_isInitialized) {
      debugPrint('VoiceService: Engine not available, retrying in 5s...');
      _scheduleRestart(const Duration(seconds: 5));
      return;
    }

    await _loadTriggers();
    await _beginListening();
  }

  void stopListening() {
    debugPrint('VoiceService: Stopped by user.');
    _isActive = false;
    _isListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    _speech.cancel();
    _listeningController.add(false); // notify UI
  }

  // ─── Internal ────────────────────────────────────────────────────────────────

  Future<void> _initEngine() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: true,
      );
      debugPrint('VoiceService: Engine initialized = $_isInitialized');
    } catch (e) {
      debugPrint('VoiceService: Init error = $e');
      _isInitialized = false;
    }
  }

  void _onStatus(String status) {
    debugPrint('VoiceService status: $status');
    if ((status == 'done' || status == 'notListening') && _isActive) {
      _isListening = false;
      _listeningController.add(false);
      // Re-check the user's setting before auto-restarting
      _scheduleRestartIfEnabled();
    }
  }

  void _onError(dynamic error) {
    final msg = error?.errorMsg?.toString() ?? error.toString();
    debugPrint('VoiceService error: $msg');
    _isListening = false;

    if (_isActive) {
      final delay = msg.contains('network')
          ? const Duration(seconds: 3)
          : const Duration(seconds: 2);
      _scheduleRestartIfEnabled(delay: delay);
    }
  }

  Future<void> _beginListening() async {
    if (_isListening || !_isActive) return;
    if (_speech.isListening) {
      await _speech.cancel();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _restartTimer?.cancel();
    _isListening = true;
    _listeningController.add(true); // notify UI — mic is now ON

    debugPrint('VoiceService: 🎙️ NOW LISTENING for: $_triggers');

    try {
      _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 10),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
        // No localeId — use device default (safest cross-device)
      );

      // Safety restart after 31 seconds in case the engine silently stops
      _restartTimer = Timer(const Duration(seconds: 31), () {
        if (_isActive) {
          debugPrint('VoiceService: Safety restart triggered.');
          _isListening = false;
          _beginListening();
        }
      });
    } catch (e) {
      debugPrint('VoiceService: listen() threw: $e');
      _isListening = false;
      _scheduleRestart(const Duration(seconds: 2));
    }
  }

  void _onResult(dynamic result) {
    final heard = (result.recognizedWords as String).toLowerCase().trim();
    if (heard.isEmpty || _alertInProgress) return;

    debugPrint('VoiceService heard: "$heard"');

    for (final trigger in _triggers) {
      if (heard.contains(trigger.toLowerCase())) {
        debugPrint('🚨 VOICE TRIGGER: "$trigger" detected!');
        _alertInProgress = true;
        unawaited(AlertService().triggerAlert());
        // Allow re-triggering after 15 seconds
        Future.delayed(const Duration(seconds: 15), () {
          _alertInProgress = false;
        });
        break;
      }
    }
  }

  void _scheduleRestart(Duration delay) {
    _restartTimer?.cancel();
    if (!_isActive) return; // hard stop — don't restart if user turned off
    _restartTimer = Timer(delay, () {
      if (_isActive && !_isListening) {
        _beginListening();
      }
    });
  }

  /// Restart only if SharedPreferences says voice is still enabled.
  /// This is the safe path called from auto-restart on status/error callbacks.
  void _scheduleRestartIfEnabled({Duration? delay}) {
    _restartTimer?.cancel();
    if (!_isActive) return;
    SharedPreferences.getInstance().then((prefs) {
      final enabled = prefs.getBool('voice_enabled') ?? true;
      if (!enabled) {
        debugPrint(
          'VoiceService: voice_enabled = false. Stopping auto-restart.',
        );
        _isActive = false;
        _listeningController.add(false);
        return;
      }
      _scheduleRestart(delay ?? const Duration(milliseconds: 800));
    });
  }

  Future<void> _loadTriggers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getStringList('custom_voice_triggers') ?? ['help'];
      _triggers = {
        'help', 'sos', 'emergency', 'bachao', 'madad', // always included
        ...custom,
      }.toList();
      debugPrint('VoiceService triggers: $_triggers');
    } catch (e) {
      debugPrint('VoiceService: Could not load triggers: $e');
    }
  }
}
