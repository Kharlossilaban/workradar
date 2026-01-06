import 'package:flutter/material.dart';
import 'package:workradar/core/storage/secure_storage.dart';
import 'package:workradar/features/auth/screens/login_screen.dart';
import 'package:workradar/features/main/screens/main_screen.dart';

/// Auth Check Screen - Auto-login if token exists
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Small delay untuk splash effect
    await Future.delayed(const Duration(milliseconds: 1500));

    // Check if user logged in
    final isLoggedIn = await SecureStorage.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        // Navigate to Main Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        // Navigate to Login Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or app name
            Icon(Icons.radar, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Workradar',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
