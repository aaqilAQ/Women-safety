import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthState { login, signup }

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  AuthState _authState = AuthState.login;
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _submit() async {
    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    try {
      if (_authState == AuthState.login) {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else if (_authState == AuthState.signup) {
        await authService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final newUser = UserModel(
            uid: uid,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
          await authService.saveUser(newUser);
        }
      }

      // Navigate to home after successful sign-in or sign-up
      if (mounted && FirebaseAuth.instance.currentUser != null) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
        return;
      }
    } on FirebaseAuthException catch (e) {
      String message = "Authentication failed";

      switch (e.code) {
        case 'user-not-found':
          message = "No user found with this email.";
          break;
        case 'wrong-password':
          message = "Incorrect password. Please try again.";
          break;
        case 'email-already-in-use':
          message = "This email is already registered.";
          break;
        case 'weak-password':
          message = "The password provided is too weak.";
          break;
        case 'invalid-email':
          message = "The email address is not valid.";
          break;
        case 'user-disabled':
          message = "This user account has been disabled.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Please try again later.";
          break;
        case 'network-request-failed':
          message = "Network error. Please check your internet connection.";
          break;
        default:
          message = e.message ?? "An unexpected error occurred.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  width: 120,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                _authState == AuthState.login ? "Sign In" : "Sign Up",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _authState == AuthState.login
                    ? "welcome back\nyou've been missed"
                    : "create account\njoin us to stay safe",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),

              _buildFormFields(),

              const SizedBox(height: 40),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : ElevatedButton(
                      onPressed: _submit,
                      child: Text(_getButtonText()),
                    ),

              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _authState = _authState == AuthState.login
                        ? AuthState.signup
                        : AuthState.login;
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                      children: [
                        TextSpan(
                          text: _authState == AuthState.login
                              ? "Don't have an account? "
                              : "Already have an account? ",
                        ),
                        TextSpan(
                          text: _authState == AuthState.login
                              ? "sign up"
                              : "sign in",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    switch (_authState) {
      case AuthState.login:
        return "Sign In";
      case AuthState.signup:
        return "Sign Up";
    }
  }

  Widget _buildFormFields() {
    switch (_authState) {
      case AuthState.login:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel("Email ID"),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(hintText: "Enter Email ID"),
            ),
            const SizedBox(height: 20),
            _buildFieldLabel("Password"),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: "Enter Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.black54,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],
        );
      case AuthState.signup:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel("Full Name"),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: "Enter Full Name"),
            ),
            const SizedBox(height: 20),
            _buildFieldLabel("Phone Number"),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(hintText: "Enter Phone Number"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _buildFieldLabel("Email ID"),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(hintText: "Enter Email ID"),
            ),
            const SizedBox(height: 20),
            _buildFieldLabel("Password"),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: "Enter Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.black54,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }
}
