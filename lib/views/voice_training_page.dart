import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceTrainingPage extends StatefulWidget {
  const VoiceTrainingPage({super.key});

  @override
  State<VoiceTrainingPage> createState() => _VoiceTrainingPageState();
}

class _VoiceTrainingPageState extends State<VoiceTrainingPage> {
  final TextEditingController _customController = TextEditingController();
  List<String> _savedTriggers = [];
  bool _isSaving = false;

  // How many words can you have
  static const int _maxTriggers = 5;

  // Suggested quick words grouped by category
  final List<Map<String, dynamic>> _suggestions = [
    {'word': 'help', 'emoji': '🆘', 'category': 'Universal'},
    {'word': 'rescue', 'emoji': '🚁', 'category': 'Universal'},
    {'word': 'danger', 'emoji': '⚠️', 'category': 'Universal'},
    {'word': 'fire', 'emoji': '🔥', 'category': 'Loud & Short'},
    {'word': 'stop', 'emoji': '✋', 'category': 'Loud & Short'},
    {'word': 'sos', 'emoji': '🔴', 'category': 'Loud & Short'},
    {'word': 'emergency', 'emoji': '🚨', 'category': 'Clear'},
    {'word': 'bachao', 'emoji': '🙏', 'category': 'Hindi'},
    {'word': 'madad', 'emoji': '🤝', 'category': 'Hindi'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedTriggers();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTriggers() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> triggers = prefs.getStringList('custom_voice_triggers') ?? [];

    // Ensure 'help' is always saved as default if nothing exists
    if (triggers.isEmpty) {
      triggers = ['help'];
      await prefs.setStringList('custom_voice_triggers', triggers);
      await prefs.setBool('voice_trained', true);
    }

    setState(() => _savedTriggers = triggers);
  }

  Future<void> _saveWord(String word) async {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return;

    if (_savedTriggers.contains(clean)) {
      _showSnack('"$clean" is already saved!', isError: true);
      return;
    }
    if (_savedTriggers.length >= _maxTriggers) {
      _showSnack(
        'Maximum $_maxTriggers words reached. Delete one first.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final updated = [..._savedTriggers, clean];
    await prefs.setStringList('custom_voice_triggers', updated);
    await prefs.setBool('voice_trained', true);

    HapticFeedback.mediumImpact();

    await _loadSavedTriggers();
    setState(() => _isSaving = false);
    _customController.clear();

    _showSnack('✅ "$clean" saved as emergency trigger!', isError: false);
  }

  Future<void> _deleteWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = _savedTriggers.where((w) => w != word).toList();
    await prefs.setStringList('custom_voice_triggers', updated);
    await _loadSavedTriggers();
    _showSnack('"$word" removed.', isError: false);
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

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
          'Voice Trigger Setup',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildInfoBanner(),
                  const SizedBox(height: 24),
                  _buildActiveWords(),
                  const SizedBox(height: 28),
                  _buildSuggestions(),
                  const SizedBox(height: 28),
                  _buildCustomInput(),
                  const SizedBox(height: 24),
                  _buildHowItWorks(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom done button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: _savedTriggers.isEmpty
                    ? null
                    : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _savedTriggers.isEmpty
                      ? 'Add at least one word to continue'
                      : 'Done — ${_savedTriggers.length} trigger word${_savedTriggers.length > 1 ? "s" : ""} active',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🎙️', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Your Emergency Word',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'When SafeStep hears this word, it instantly sends SOS alerts to your contacts.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWords() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Trigger Words',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${_savedTriggers.length}/$_maxTriggers',
              style: TextStyle(
                color: _savedTriggers.length >= _maxTriggers
                    ? Colors.orange
                    : Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_savedTriggers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Text('🗣️', style: TextStyle(fontSize: 32)),
                SizedBox(height: 8),
                Text(
                  'No trigger words yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap any suggestion below or type your own',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _savedTriggers
                .map(
                  (word) => Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic, size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            '"$word"',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteWord(word),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildSuggestions() {
    // Group by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in _suggestions) {
      final cat = s['category'] as String;
      grouped.putIfAbsent(cat, () => []).add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Add',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap any word to instantly add it.',
          style: TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map(
          (entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.value.map((s) {
                  final alreadySaved = _savedTriggers.contains(s['word']);
                  return GestureDetector(
                    onTap: alreadySaved ? null : () => _saveWord(s['word']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: alreadySaved
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: alreadySaved
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s['emoji'],
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s['word'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: alreadySaved
                                  ? Colors.green
                                  : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          if (alreadySaved) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green,
                            ),
                          ] else ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.add_circle_outline,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Or Type Your Own Word',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.done,
                onSubmitted: _saveWord,
                decoration: InputDecoration(
                  hintText: 'e.g. tiger, rainbow, shout...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: Icon(
                    Icons.edit_outlined,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () => _saveWord(_customController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(72, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Tips for Best Results',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            'Choose a word you would naturally shout in danger',
            'Short words (1-2 syllables) work best: "Help", "Fire", "Stop"',
            'Hindi words like "Bachao" or "Madad" work too',
            'Make sure Protection is Active on the Home screen',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
