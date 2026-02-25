import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

/// Holds live accelerometer data during training.
class ShakeSample {
  final double x, y, z;
  final double magnitude;
  ShakeSample(this.x, this.y, this.z)
    : magnitude = math.sqrt(x * x + y * y + z * z);
}

/// Result produced after training completes.
class ShakeTrainingResult {
  final double thresholdX;
  final double thresholdY;
  final double thresholdZ;
  final double peakMagnitude;
  final int totalSamples;

  ShakeTrainingResult({
    required this.thresholdX,
    required this.thresholdY,
    required this.thresholdZ,
    required this.peakMagnitude,
    required this.totalSamples,
  });
}

class ShakeTrainer {
  static final ShakeTrainer _instance = ShakeTrainer._internal();
  factory ShakeTrainer() => _instance;
  ShakeTrainer._internal();

  bool isTraining = false;
  List<ShakeSample> _samples = [];
  StreamSubscription<AccelerometerEvent>? _subscription;

  /// Streams live samples to the UI while training.
  final StreamController<ShakeSample> _liveController =
      StreamController<ShakeSample>.broadcast();
  Stream<ShakeSample> get liveStream => _liveController.stream;

  /// Duration of training in seconds.
  static const int trainingDurationSeconds = 3;

  /// Start a 3-second training session.
  /// [onProgress] reports 0.0→1.0 progress.
  /// [onComplete] is called with the resulting thresholds.
  Future<void> startTraining(
    Function(double progress) onProgress,
    Function(ShakeTrainingResult result) onComplete,
  ) async {
    if (isTraining) return;
    isTraining = true;
    _samples = [];

    // Target: ~50Hz × 3 seconds = 150 samples
    const int targetSamples = 150;

    _subscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!isTraining) return;

      final sample = ShakeSample(event.x, event.y, event.z);
      _samples.add(sample);
      _liveController.add(sample);

      double progress = _samples.length / targetSamples;
      onProgress(progress.clamp(0.0, 1.0));

      if (_samples.length >= targetSamples) {
        _finishTraining(onComplete);
      }
    });

    // Safety auto-stop after training duration + 1 second buffer
    Future.delayed(const Duration(seconds: trainingDurationSeconds + 1), () {
      if (isTraining) _finishTraining(onComplete);
    });
  }

  void cancelTraining() {
    isTraining = false;
    _subscription?.cancel();
    _subscription = null;
    _samples = [];
  }

  void _finishTraining(Function(ShakeTrainingResult result) onComplete) async {
    isTraining = false;
    _subscription?.cancel();
    _subscription = null;

    if (_samples.isEmpty) {
      onComplete(
        ShakeTrainingResult(
          thresholdX: 25.0,
          thresholdY: 25.0,
          thresholdZ: 25.0,
          peakMagnitude: 0,
          totalSamples: 0,
        ),
      );
      return;
    }

    final result = await _calculateAndSaveThresholds();
    onComplete(result);
  }

  Future<ShakeTrainingResult> _calculateAndSaveThresholds() async {
    double maxX = 0;
    double maxY = 0;
    double maxZ = 0;
    double peakMag = 0;

    for (var sample in _samples) {
      maxX = math.max(maxX, sample.x.abs());
      maxY = math.max(maxY, sample.y.abs());
      maxZ = math.max(maxZ, sample.z.abs());
      peakMag = math.max(peakMag, sample.magnitude);
    }

    // Threshold is 80% of maximum recorded (so the same shake will trigger).
    // Minimum threshold of 15.0 to avoid accidental triggers from normal movement.
    final thX = math.max(15.0, maxX * 0.8);
    final thY = math.max(15.0, maxY * 0.8);
    final thZ = math.max(15.0, maxZ * 0.8);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('shake_threshold_x', thX);
    await prefs.setDouble('shake_threshold_y', thY);
    await prefs.setDouble('shake_threshold_z', thZ);
    await prefs.setBool('shake_trained', true);

    return ShakeTrainingResult(
      thresholdX: thX,
      thresholdY: thY,
      thresholdZ: thZ,
      peakMagnitude: peakMag,
      totalSamples: _samples.length,
    );
  }

  Future<Map<String, double>> getThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'x': prefs.getDouble('shake_threshold_x') ?? 25.0,
      'y': prefs.getDouble('shake_threshold_y') ?? 25.0,
      'z': prefs.getDouble('shake_threshold_z') ?? 25.0,
    };
  }

  Future<bool> get isTrained async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('shake_trained') ?? false;
  }
}
