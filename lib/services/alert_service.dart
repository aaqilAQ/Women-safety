import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  Future<void> triggerAlert() async {
    debugPrint("🚨 EMERGENCY TRIGGERED 🚨");
    
    // 1. Get Location
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint("Location error: $e");
      // Fallback or retry logic could go here
      return;
    }

    // 2. Get User & Contacts (Direct Firestore access might need initialization in background isolate)
    // In a real background isolate, FirebaseAuth instance might need to be refreshed or passed via shared preferences if the isolate is completely separate.
    // However, for this MVP, we assume standard isolate usage or that we are in foreground/background-fetch where Firebase is initialized.
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("No user logged in to send alert.");
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List<dynamic> contacts = userData['emergencyContacts'] ?? [];
      String name = userData['name'] ?? 'User';

      String googleMapsLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
      String message = "🚨 EMERGENCY 🚨\n$name needs HELP!\nLocation: $googleMapsLink";

      // 3. Send SMS (Preview)
      // Note: On Android, 'sms:' uri usually opens the app. 
      // To send automatically in background, you'd need 'telephony_sms' or similar and 'SEND_SMS' permission.
      // We follow the prompt's request for url_launcher.
      
      for (var contact in contacts) {
        String phone = contact['phone'];
        final Uri smsLaunchUri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: <String, String>{
            'body': message,
          },
        );
        
        debugPrint("Launching SMS to $phone");
        if (await canLaunchUrl(smsLaunchUri)) {
          await launchUrl(smsLaunchUri); 
        } else {
             // Fallback for some android versions
             await launchUrl(Uri.parse("sms:$phone?body=$message"));
        }
      }
    } catch (e) {
      debugPrint("Error sending alert: $e");
    }
  }
}
