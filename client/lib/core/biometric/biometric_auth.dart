import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Biometric Authentication helper
class BiometricAuth {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device supports biometric authentication
  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, iris)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate with biometric
  static Future<bool> authenticate({
    String reason = 'Please authenticate to access Workradar',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final isAvailable = await BiometricAuth.isAvailable();
      if (!isAvailable) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false, // Allow PIN/pattern as fallback
        ),
      );
    } on PlatformException catch (e) {
      print('[BiometricAuth] Error: ${e.message}');
      return false;
    } catch (e) {
      print('[BiometricAuth] Unexpected error: $e');
      return false;
    }
  }

  /// Stop ongoing authentication
  static Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      print('[BiometricAuth] Error stopping: $e');
    }
  }
}
