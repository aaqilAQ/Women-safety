import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shake_trainer.dart';

class ShakeTrainingPage extends StatefulWidget {
  const ShakeTrainingPage({super.key});

  @override
  State<ShakeTrainingPage> createState() => _ShakeTrainingPageState();
}

class _ShakeTrainingPageState extends State<ShakeTrainingPage>
    with TickerProviderStateMixin {
  // ── State machine ──────────────────────────────────────────────────────────
  _TrainingPhase _phase = _TrainingPhase.intro;
  double _progress = 0.0;
  ShakeTrainingResult? _result;
  Map<String, double>? _currentThresholds;
  bool _wasTrained = false;

  // ── Live accelerometer visualisation ───────────────────────────────────────
  double _liveX = 0, _liveY = 0, _liveZ = 0;
  double _liveMagnitude = 0;
  double _peakMagnitude = 0;
  StreamSubscription<ShakeSample>? _liveSub;

  // ── Countdown ──────────────────────────────────────────────────────────────
  int _countdown = 3;
  Timer? _countdownTimer;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _shakeIconCtrl;

  @override
  void initState() {
    super.initState();
    _loadExistingThresholds();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shakeIconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _shakeIconCtrl.dispose();
    ShakeTrainer().cancelTraining();
    super.dispose();
  }

  Future<void> _loadExistingThresholds() async {
    final thresholds = await ShakeTrainer().getThresholds();
    final trained = await ShakeTrainer().isTrained;
    if (mounted) {
      setState(() {
        _currentThresholds = thresholds;
        _wasTrained = trained;
      });
    }
  }

  // ── Start countdown → then training ────────────────────────────────────────
  void _startCountdown() {
    setState(() {
      _phase = _TrainingPhase.countdown;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        _startRecording();
      } else {
        HapticFeedback.mediumImpact();
        setState(() => _countdown--);
      }
    });
  }

  void _startRecording() {
    setState(() {
      _phase = _TrainingPhase.recording;
      _progress = 0.0;
      _peakMagnitude = 0;
    });

    HapticFeedback.heavyImpact();

    // Subscribe to live visualisation stream
    _liveSub = ShakeTrainer().liveStream.listen((sample) {
      if (mounted) {
        setState(() {
          _liveX = sample.x;
          _liveY = sample.y;
          _liveZ = sample.z;
          _liveMagnitude = sample.magnitude;
          if (sample.magnitude > _peakMagnitude) {
            _peakMagnitude = sample.magnitude;
          }
        });
        // Shake the icon
        _shakeIconCtrl.forward().then((_) => _shakeIconCtrl.reverse());
      }
    });

    ShakeTrainer().startTraining(
      (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      (result) {
        _liveSub?.cancel();
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _phase = _TrainingPhase.result;
            _result = result;
          });
          _loadExistingThresholds(); // refresh displayed thresholds
        }
      },
    );
  }

  void _retrain() {
    setState(() {
      _phase = _TrainingPhase.intro;
      _result = null;
      _progress = 0;
      _liveX = 0;
      _liveY = 0;
      _liveZ = 0;
      _liveMagnitude = 0;
      _peakMagnitude = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shake Training',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildPhaseContent(),
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case _TrainingPhase.intro:
        return _buildIntroPhase();
      case _TrainingPhase.countdown:
        return _buildCountdownPhase();
      case _TrainingPhase.recording:
        return _buildRecordingPhase();
      case _TrainingPhase.result:
        return _buildResultPhase();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 1: INTRO — explain what will happen
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildIntroPhase() {
    return Padding(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Hero illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.shade200.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.vibration, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 32),

          const Text(
            'Train Your Shake Pattern',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Shake your phone the way you would in an emergency.\n'
            'SafeStep will learn your pattern and only trigger SOS\n'
            'when it detects that exact intensity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Steps
          _buildStepRow('1', 'Get ready — hold your phone firmly'),
          _buildStepRow('2', 'A 3-second countdown will begin'),
          _buildStepRow('3', 'Shake vigorously for 3 seconds'),
          _buildStepRow('4', 'Your shake pattern is saved'),

          if (_wasTrained && _currentThresholds != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Already trained — X: ${_currentThresholds!['x']!.toStringAsFixed(1)}, '
                      'Y: ${_currentThresholds!['y']!.toStringAsFixed(1)}, '
                      'Z: ${_currentThresholds!['z']!.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(flex: 2),

          // Start button
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: ElevatedButton(
              onPressed: _startCountdown,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                _wasTrained ? 'Re-Train Shake Pattern' : 'Start Training',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 2: COUNTDOWN — 3, 2, 1...
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCountdownPhase() {
    return Center(
      key: const ValueKey('countdown'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Get Ready!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 40),
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade300.withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Hold your phone firmly...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 3: RECORDING — shake now! live visualisation
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRecordingPhase() {
    final normalizedMag = (_liveMagnitude / 50.0).clamp(0.0, 1.0);

    return Padding(
      key: const ValueKey('recording'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Animated "SHAKE NOW" label
          Text(
            '📳 SHAKE NOW!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.red.shade700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shake as hard as you would in an emergency',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 40),

          // Live magnitude ring
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 12,
                    color: Colors.grey.shade200,
                  ),
                ),
                // Active ring
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: normalizedMag,
                    strokeWidth: 12,
                    color: Color.lerp(Colors.orange, Colors.red, normalizedMag),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Center: vibration icon
                AnimatedBuilder(
                  animation: _shakeIconCtrl,
                  builder: (context, child) {
                    final shake = math.sin(_shakeIconCtrl.value * math.pi) * 6;
                    return Transform.translate(
                      offset: Offset(shake, 0),
                      child: child,
                    );
                  },
                  child: Icon(
                    Icons.vibration,
                    size: 48,
                    color: Color.lerp(
                      Colors.orange.shade400,
                      Colors.red.shade600,
                      normalizedMag,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Live axis readouts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAxisChip('X', _liveX, Colors.red),
              _buildAxisChip('Y', _liveY, Colors.green),
              _buildAxisChip('Z', _liveZ, Colors.blue),
            ],
          ),

          const SizedBox(height: 12),

          // Peak magnitude
          Text(
            'Peak: ${_peakMagnitude.toStringAsFixed(1)} m/s²',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 32),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}% — ${(3 - _progress * 3).clamp(0, 3).toStringAsFixed(1)}s remaining',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildAxisChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 4: RESULT — show calibrated thresholds
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildResultPhase() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();

    final isStrong = r.peakMagnitude > 20;

    return Padding(
      key: const ValueKey('result'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),

          // Success icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isStrong ? Colors.green.shade50 : Colors.orange.shade50,
              boxShadow: [
                BoxShadow(
                  color: (isStrong ? Colors.green : Colors.orange).withValues(
                    alpha: 0.2,
                  ),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              isStrong ? Icons.check_circle : Icons.warning_rounded,
              size: 56,
              color: isStrong ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            isStrong ? 'Pattern Saved!' : 'Shake Was Too Gentle',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isStrong ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isStrong
                ? 'Your shake pattern has been calibrated.\nSafeStep will trigger SOS when it detects this intensity.'
                : 'Try shaking harder next time.\nA weak shake may cause false triggers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Threshold card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  'Calibrated Thresholds',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildThresholdStat('X-Axis', r.thresholdX, Colors.red),
                    _buildThresholdStat('Y-Axis', r.thresholdY, Colors.green),
                    _buildThresholdStat('Z-Axis', r.thresholdZ, Colors.blue),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSmallStat(
                      'Peak Force',
                      '${r.peakMagnitude.toStringAsFixed(1)} m/s²',
                    ),
                    _buildSmallStat('Samples', '${r.totalSamples}'),
                    _buildSmallStat('Duration', '3 sec'),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _retrain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Colors.black26),
                  ),
                  child: const Text(
                    'Re-Train',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildThresholdStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

enum _TrainingPhase { intro, countdown, recording, result }
