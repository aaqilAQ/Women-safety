import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user != null) {
      UserModel? userData = await authService.getUser(user.uid);
      if (userData != null) {
        setState(() {
          _selectedContacts = userData.emergencyContacts;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickContact() async {
    if (await Permission.contacts.request().isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        if (phone.isNotEmpty) {
           _addContact(contact.displayName, phone);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected contact has no phone number")));
        }
      }
    }
  }

  void _addContact(String name, String phone) {
    if (_selectedContacts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 5 contacts allowed")));
      return;
    }
    setState(() {
      _selectedContacts.add(ContactModel(name: name, phone: phone, relation: "Friend"));
    });
  }

  Future<void> _saveContacts() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user != null) {
      await authService.updateContacts(user.uid, _selectedContacts);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Contacts")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Add up to 5 trusted contacts who will receive your SOS alerts.",
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _selectedContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _selectedContacts[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(contact.name),
                        subtitle: Text(contact.phone),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedContacts.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickContact,
                        icon: const Icon(Icons.contact_phone),
                        label: const Text("Pick from Contacts"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _saveContacts,
                        child: const Text("Save & Continue"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
