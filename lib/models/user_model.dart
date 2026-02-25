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
    this.emergencyContacts = const [],
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'name': name,
      'phone': phone,
      'isActive': isActive,
    };
    // Only include emergencyContacts if there are any.
    // This avoids Pigeon type serialization issues with empty lists.
    if (emergencyContacts.isNotEmpty) {
      map['emergencyContacts'] = List<Map<String, dynamic>>.from(
        emergencyContacts.map((c) => c.toMap()),
      );
    }
    return map;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final rawContacts = map['emergencyContacts'];
    final List<ContactModel> contacts = [];
    if (rawContacts != null && rawContacts is List) {
      for (final item in rawContacts) {
        if (item is Map) {
          contacts.add(ContactModel.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      emergencyContacts: contacts,
      isActive: map['isActive'] ?? true,
    );
  }
}
