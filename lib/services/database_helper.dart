import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const String _boxName = 'contacts_box';

  /// Call this once in main() before runApp()
  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Map>(_boxName);
    }
  }

  Box<Map> get _box => Hive.box<Map>(_boxName);

  Future<void> saveAllContacts(List<ContactModel> contacts) async {
    try {
      await _box.clear();
      for (int i = 0; i < contacts.length; i++) {
        await _box.put(i, contacts[i].toMap());
      }
      debugPrint("Hive: Saved ${contacts.length} contacts.");
    } catch (e) {
      debugPrint("Hive: Error saving contacts: $e");
      rethrow;
    }
  }

  Future<List<ContactModel>> getContacts() async {
    try {
      return _box.values
          .map((m) => ContactModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint("Hive: Error reading contacts: $e");
      return [];
    }
  }

  Future<void> deleteContact(String phone) async {
    try {
      final key = _box.keys.firstWhere(
        (k) => _box.get(k)?['phone'] == phone,
        orElse: () => null,
      );
      if (key != null) await _box.delete(key);
    } catch (e) {
      debugPrint("Hive: Error deleting contact: $e");
    }
  }
}
