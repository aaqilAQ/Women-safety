import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/background_service.dart';
import 'services/auth_service.dart';
import 'views/auth_screen.dart';
import 'views/home_screen.dart';
import 'views/contacts_screen.dart';
import 'config/theme.dart';
import 'views/stealth_screen.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        StreamProvider(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'SafeStep',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        home: const AuthWrapper(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/contacts': (context) => const ContactsSetupScreen(),
          '/auth': (context) => const AuthScreen(),
          '/stealth': (context) => const StealthScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool>? _stealthFuture;

  @override
  void initState() {
    super.initState();
    _stealthFuture = _isStealthEnabled();
  }

  Future<bool> _isStealthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('stealth_mode') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();

    if (user != null) {
      return FutureBuilder<bool>(
        future: _stealthFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            );
          }
          if (snapshot.data == true) {
            return const StealthScreen();
          }
          return const HomeScreen();
        },
      );
    }
    return const AuthScreen();
  }
}
