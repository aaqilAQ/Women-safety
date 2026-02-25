import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userEmail;
  final String complaint;
  final DateTime timestamp;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;

  ComplaintModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
    required this.complaint,
    required this.timestamp,
    this.status = 'pending',
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'complaint': complaint,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
    };
  }

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String id) {
    return ComplaintModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      userEmail: map['userEmail'] ?? '',
      complaint: map['complaint'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      locationAddress: map['locationAddress'],
    );
  }
}
