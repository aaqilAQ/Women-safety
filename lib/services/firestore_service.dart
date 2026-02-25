import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/complaint_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Push a new complaint to Firestore.
  /// Throws a user-friendly exception if auth or permissions fail.
  Future<void> registerComplaint(ComplaintModel complaint) async {
    // 1. Check authentication first
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to submit a complaint.');
    }

    // 2. Ensure the complaint.userId matches the currently logged-in user
    //    (this is required by our Firestore security rules)
    final data = complaint.toMap();
    data['userId'] =
        user.uid; // Force correct userId regardless of what was passed

    try {
      await _db.collection('complaints').add(data);
      debugPrint('FirestoreService: Complaint registered successfully.');
    } on FirebaseException catch (e) {
      debugPrint('FirestoreService: Firestore error → ${e.code}: ${e.message}');

      if (e.code == 'permission-denied') {
        throw Exception(
          'Firestore permission denied. '
          'Please update your Firestore Security Rules to allow authenticated users '
          'to write to the "complaints" collection. '
          'See the firestore.rules file in your project root.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('FirestoreService: Unexpected error → $e');
      rethrow;
    }
  }

  /// Push an alert event to Firestore (real-time tracking).
  Future<void> logAlertEvent({
    required String userId,
    required String triggerType,
    double? latitude,
    double? longitude,
    String? locationText,
    bool smsSent = false,
  }) async {
    // Use the currently logged-in user's UID if available
    final user = _auth.currentUser;
    final effectiveUserId = user?.uid ?? userId;

    final data = {
      'userId': effectiveUserId,
      'triggerType': triggerType,
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': latitude,
      'longitude': longitude,
      'locationText': locationText,
      'smsSent': smsSent,
    };

    try {
      await _db.collection('alerts').add(data);
      debugPrint('FirestoreService: Alert event logged successfully.');
    } on FirebaseException catch (e) {
      debugPrint(
        'FirestoreService: Alert log failed → ${e.code}: ${e.message}',
      );
      // Don't throw for alert logging — SMS sending is more critical.
      // Just log the error silently.
    } catch (e) {
      debugPrint('FirestoreService: Unexpected alert log error → $e');
    }
  }
}
