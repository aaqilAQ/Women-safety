import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithPhone(
    String phoneNumber,
    Function(String, int?) codeSent,
    Function(FirebaseAuthException) verificationFailed,
  ) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  // Simplified email login for MVP if needed, but phone is primary for safety apps usually
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // If sign-in succeeded but Pigeon failed to deserialize the return,
      // the user is still signed in. Check currentUser.
      if (_auth.currentUser != null) {
        debugPrint('AuthService: Sign-in succeeded (Pigeon return ignored).');
        return;
      }
      rethrow;
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // If auth succeeded but Pigeon failed to deserialize the return value,
      // the user is still created. Check if we're now signed in.
      if (_auth.currentUser != null) {
        debugPrint('AuthService: Sign-up succeeded (Pigeon return ignored).');
        return;
      }
      // If auth actually failed, rethrow
      rethrow;
    }
  }

  Future<void> saveUser(UserModel user) async {
    try {
      debugPrint('AuthService: Saving user ${user.uid} to Firestore...');
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.name,
        'phone': user.phone,
        'isActive': user.isActive,
      });
      debugPrint('AuthService: User saved successfully.');
    } catch (e) {
      debugPrint('AuthService: ERROR saving user: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      return UserModel.fromMap(data, uid);
    }
    return null;
  }

  Future<void> updateContacts(String uid, List<ContactModel> contacts) async {
    // Build a Pigeon-safe list of plain maps
    final List<Map<String, String>> contactMaps = [];
    for (final c in contacts) {
      contactMaps.add({
        'name': c.name,
        'phone': c.phone,
        'relation': c.relation,
      });
    }
    await _firestore.collection('users').doc(uid).set({
      'emergencyContacts': contactMaps,
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
