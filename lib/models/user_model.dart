
import 'contact_model.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final List<ContactModel> emergencyContacts;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.emergencyContacts,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'emergencyContacts': emergencyContacts.map((c) => c.toMap()).toList(),
      'isActive': isActive,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      emergencyContacts: (map['emergencyContacts'] as List<dynamic>?)
              ?.map((item) => ContactModel.fromMap(item))
              .toList() ??
          [],
      isActive: map['isActive'] ?? true,
    );
  }
}
