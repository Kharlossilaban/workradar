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
    print('[AuthCheck] 🚀 Starting auth status check...');

    // Small delay untuk splash effect
    await Future.delayed(const Duration(milliseconds: 1500));

    // Check if user logged in
    print('[AuthCheck] 🔍 Checking login status...');
    final isLoggedIn = await SecureStorage.isLoggedIn();
    print('[AuthCheck] 📊 Login status: $isLoggedIn');

    if (isLoggedIn) {
      // Debug: Check actual token values
      final accessToken = await SecureStorage.getAccessToken();
      final refreshToken = await SecureStorage.getRefreshToken();
      final email = await SecureStorage.getUserEmail();
      print('[AuthCheck] 🎫 Access Token: ${accessToken?.substring(0, 20)}...');
      print(
        '[AuthCheck] 🔄 Refresh Token: ${refreshToken?.substring(0, 20)}...',
      );
      print('[AuthCheck] 📧 User Email: $email');
    }

    if (mounted) {
      if (isLoggedIn) {
        // Navigate to Main Screen
        print('[AuthCheck] ✅ User is logged in → Navigating to MainScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        // Navigate to Login Screen
        print(
          '[AuthCheck] ⚠️ User is NOT logged in → Navigating to LoginScreen',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      print('[AuthCheck] ⚠️ Widget not mounted, skipping navigation');
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
