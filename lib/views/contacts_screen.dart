import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_helper.dart';

class ContactsSetupScreen extends StatefulWidget {
  const ContactsSetupScreen({super.key});

  @override
  State<ContactsSetupScreen> createState() => _ContactsSetupScreenState();
}

class _ContactsSetupScreenState extends State<ContactsSetupScreen> {
  List<ContactModel> _selectedContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserContacts();
  }

  Future<void> _loadUserContacts() async {
    try {
      // 1. Try loading from SQLite first
      final localContacts = await DatabaseHelper().getContacts();
      if (localContacts.isNotEmpty && mounted) {
        setState(() {
          _selectedContacts = localContacts;
          _isLoading = false;
        });
        debugPrint("Contacts: Loaded from SQLite");
      }

      // 2. Refresh from Firebase to ensure sync
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user != null) {
        UserModel? userData = await authService.getUser(user.uid);
        if (userData != null && mounted) {
          setState(() {
            _selectedContacts = List.from(userData.emergencyContacts);
            _isLoading = false;
          });
          // Update SQLite if different
          await DatabaseHelper().saveAllContacts(_selectedContacts);
          return;
        }
      }
    } catch (e) {
      debugPrint("Error loading contacts: $e");
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickContact() async {
    var status = await Permission.contacts.request();

    if (status.isGranted) {
      try {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          final fullContact = await FlutterContacts.getContact(contact.id);
          final phone = (fullContact?.phones.isNotEmpty ?? false)
              ? fullContact!.phones.first.number.replaceAll(
                  RegExp(r'[^\d+]'),
                  '',
                )
              : '';

          if (phone.isNotEmpty) {
            _addContact(fullContact?.displayName ?? "Unknown", phone);
          } else {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Selected contact has no phone number"),
                ),
              );
          }
        }
      } catch (e) {
        debugPrint("Contact picker error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open contact picker: $e")),
          );
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Permission Required"),
            content: const Text(
              "Contact permission is permanently denied. Please enable it in settings to pick contacts.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text("Settings"),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showManualContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Add Contact Manually",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Contact Name"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: "Phone Number"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                _addContact(
                  nameController.text.trim(),
                  phoneController.text.trim().replaceAll(RegExp(r'[^\d+]'), ''),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _addContact(String name, String phone) {
    if (_selectedContacts.length >= 5) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Max 5 contacts allowed")));
      return;
    }

    // Check if already exists
    if (_selectedContacts.any((c) => c.phone == phone)) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Contact already added")));
      return;
    }

    setState(() {
      _selectedContacts.add(
        ContactModel(name: name, phone: phone, relation: "Trusted"),
      );
    });
  }

  Future<void> _saveContacts() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user != null) {
      try {
        // 1. ALWAYS save to SharedPreferences first (works in all isolates)
        final prefs = await SharedPreferences.getInstance();
        final String contactsJson = jsonEncode(
          _selectedContacts.map((e) => e.toMap()).toList(),
        );
        await prefs.setString('cached_contacts', contactsJson);

        // 2. Save to Firebase (online backup)
        await authService.updateContacts(user.uid, _selectedContacts);

        // 3. Try SQLite as optional local cache (only works on main isolate)
        try {
          await DatabaseHelper().saveAllContacts(_selectedContacts);
        } catch (e) {
          debugPrint("SQLite save skipped (non-critical): $e");
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Trusted contacts saved successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save contacts: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Trusted Contacts",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Text(
                    "Add up to 5 trusted contacts who will receive your SOS alerts.",
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.5),
                      fontSize: 15,
                    ),
                  ),
                ),
                Expanded(
                  child: _selectedContacts.isEmpty
                      ? _buildEmptyState()
                      : _buildContactsList(),
                ),
                _buildActionButtons(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_phone_outlined,
            size: 80,
            color: Colors.black.withOpacity(0.1),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Trusted Contacts",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              "Start by adding contacts from your phone book or enter them manually.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _selectedContacts.length,
      itemBuilder: (context, index) {
        final contact = _selectedContacts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.05),
              child: const Icon(Icons.person_outline, color: Colors.black),
            ),
            title: Text(
              contact.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              contact.phone,
              style: TextStyle(color: Colors.black.withOpacity(0.5)),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red.withOpacity(0.7),
              ),
              onPressed: () {
                setState(() {
                  _selectedContacts.removeAt(index);
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickContact,
                  icon: const Icon(Icons.contacts, size: 18),
                  label: const Text("Phone Book"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Colors.black12),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showManualContactDialog,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Manual"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Colors.black12),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedContacts.isEmpty ? null : _saveContacts,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Save and Update",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
