import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'sms_service.dart';
import 'firestore_service.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Access global messengerKey, navigatorKey

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  bool _isAlertInProgress = false;

  Future<void> triggerAlert() async {
    if (_isAlertInProgress) return;
    _isAlertInProgress = true;

    debugPrint("🚨 EMERGENCY TRIGGERED 🚨");

    // UI Feedback: Snackbar
    try {
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("🚨 SOS Triggered! Opening status tracker..."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}

    String name = 'User';
    List<dynamic> contacts = [];
    Map<String, String> smsStatus = {}; // phone -> status

    // 2. Prepare Message & Fetch Contacts
    try {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString('cached_user_name') ?? 'User';

      // Load contacts from SharedPreferences only (SQLite unavailable in background isolates)
      final String? contactsJson = prefs.getString('cached_contacts');
      if (contactsJson != null && contactsJson.isNotEmpty) {
        contacts = jsonDecode(contactsJson);
        debugPrint(
          "AlertService: Loaded ${contacts.length} contacts from SharedPreferences.",
        );
      }

      if (contacts.isEmpty) {
        debugPrint(
          "🚨 ABORT: No emergency contacts found! Please add contacts first.",
        );
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ No emergency contacts saved! Please add contacts first.",
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _isAlertInProgress = false;
        return;
      }

      for (var c in contacts) {
        smsStatus[c['phone'].toString()] = 'Preparing...';
      }

      // Show Status Dialog if in foreground
      _showStatusDialog(smsStatus);

      // 3. Get Location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint("Location error: $e. Using last known location.");
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (e) {
          debugPrint("Could not get any location: $e");
        }
      }

      String locString = position != null
          ? "https://maps.google.com/?q=${position.latitude},${position.longitude}"
          : "Location unavailable.";

      String finalMessage =
          "🚨 EMERGENCY 🚨\n$name needs HELP!\nLocation: $locString";

      // 4. Log to Firestore (REAL-TIME TRACKING)
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirestoreService().logAlertEvent(
            userId: user.uid,
            triggerType: "emergency_trigger",
            latitude: position?.latitude,
            longitude: position?.longitude,
            locationText: locString,
            smsSent: true,
          );
          debugPrint("AlertService: Alert event logged to Firestore.");
        }
      } catch (e) {
        debugPrint("AlertService: Firestore logging failed: $e");
      }

      // 5. Send SMS Process
      debugPrint(
        "AlertService: Sending SOS messages to ${contacts.length} recipients...",
      );
      for (var contact in contacts) {
        String phone = contact['phone'].toString().replaceAll(
          RegExp(r'\s+'),
          '',
        );
        if (phone.length == 10 && !phone.startsWith('+')) phone = "+91$phone";

        _updateDialogStatus(phone, 'Sending...', smsStatus);
        debugPrint("AlertService: Sending SMS to $phone");

        try {
          bool success = await SmsService().sendSms(phone, finalMessage);
          _updateDialogStatus(
            phone,
            success ? 'SENT ✅' : 'FAILED ❌',
            smsStatus,
          );

          if (!success) {
            debugPrint(
              "AlertService: SMS failed for $phone. Attempting UI fallback.",
            );
            await _launchSmsFallback(phone, finalMessage);
          } else {
            debugPrint("AlertService: SMS SENT SUCCESSFULLY to $phone");
          }
        } catch (e) {
          debugPrint("AlertService: SmsService Error for $phone: $e");
          _updateDialogStatus(phone, 'ERROR ⚠️', smsStatus);
          await _launchSmsFallback(phone, finalMessage);
        }
      }

      _recordAmbientAudio();
    } catch (e) {
      debugPrint("AlertService Error: $e");
    } finally {
      Future.delayed(
        const Duration(seconds: 30),
        () => _isAlertInProgress = false,
      );
    }
  }

  void _showStatusDialog(Map<String, String> statusMap) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    _statusNotifier.value = Map.from(statusMap); // Initialize notifier
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EmergencyStatusModal(
        initialStatus: statusMap,
        statusNotifier: _statusNotifier,
      ),
    );
  }

  final ValueNotifier<Map<String, String>> _statusNotifier = ValueNotifier({});

  void _updateDialogStatus(
    String phone,
    String status,
    Map<String, String> statusMap,
  ) {
    statusMap[phone] = status;
    _statusNotifier.value = Map.from(statusMap);
  }

  Future<void> _recordAmbientAudio() async {
    final record = AudioRecorder();
    try {
      if (await record.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/emergency_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await record.start(const RecordConfig(), path: path);
        debugPrint("Recording ambient audio to $path");

        // Record for 60 seconds then stop
        await Future.delayed(const Duration(seconds: 60));
        await record.stop();
        debugPrint("Recording stopped.");
      }
    } catch (e) {
      debugPrint("Recording error: $e");
    } finally {
      record.dispose();
    }
  }

  Future<void> _launchSmsFallback(String phone, String message) async {
    try {
      final Uri smsLaunchUri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: <String, String>{'body': message},
      );

      // url_launcher requires a foreground activity.
      // This will throw PlatformException(NO_ACTIVITY) if called from background.
      if (await canLaunchUrl(smsLaunchUri)) {
        debugPrint("Attempting UI-based SMS fallback for $phone...");
        await launchUrl(smsLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Cannot launch SMS URL for $phone");
      }
    } catch (e) {
      // This is expected in background isolates
      debugPrint(
        "SMS fallback failed (Expected in background/locked screen): $e",
      );
    }
  }
}

class _EmergencyStatusModal extends StatelessWidget {
  final Map<String, String> initialStatus;
  final ValueNotifier<Map<String, String>> statusNotifier;

  const _EmergencyStatusModal({
    required this.initialStatus,
    required this.statusNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.security, color: Colors.red),
          SizedBox(width: 10),
          Text(
            "SOS IN PROGRESS",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ValueListenableBuilder<Map<String, String>>(
          valueListenable: statusNotifier,
          builder: (context, currentStatus, _) {
            bool allDone = currentStatus.values.every(
              (s) => s.contains('✅') || s.contains('❌') || s.contains('⚠️'),
            );
            bool allSuccess = currentStatus.values.every(
              (s) => s.contains('✅'),
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allDone && allSuccess)
                  const Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.check, color: Colors.white, size: 40),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "HELP ALERTED SUCCESSFULLY!",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                const Text(
                  "Sending emergency alerts to your trusted contacts...",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                ...currentStatus.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: entry.value.contains('✅')
                                    ? Colors.green
                                    : entry.value.contains('Sending')
                                    ? Colors.blue
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                if (allDone) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "FINISH & CLOSE",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(color: Colors.red),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
