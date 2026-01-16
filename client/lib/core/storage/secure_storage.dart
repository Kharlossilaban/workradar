import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage wrapper untuk menyimpan data sensitif (encrypted)
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true, // Auto-reset if encryption fails
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false, // Don't sync across devices
    ),
  );

  // Storage keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserType = 'user_type';
  static const String _keyUsername = 'username';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  /// Save access token
  static Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _keyAccessToken, value: token);
      print('✅ Access token saved successfully');

      // Verify save was successful
      final saved = await _storage.read(key: _keyAccessToken);
      if (saved == null) {
        print('⚠️ Warning: Token save verification failed!');
      }
    } catch (e) {
      print('❌ Error saving access token: $e');
      rethrow;
    }
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (e) {
      print('❌ Error reading access token: $e');
      return null;
    }
  }

  /// Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
      print('✅ Refresh token saved successfully');

      // Verify save was successful
      final saved = await _storage.read(key: _keyRefreshToken);
      if (saved == null) {
        print('⚠️ Warning: Refresh token save verification failed!');
      }
    } catch (e) {
      print('❌ Error saving refresh token: $e');
      rethrow;
    }
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      print('❌ Error reading refresh token: $e');
      return null;
    }
  }

  /// Save user data
  static Future<void> saveUserData({
    required String userId,
    required String email,
    required String userType,
  }) async {
    await Future.wait([
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyUserEmail, value: email),
      _storage.write(key: _keyUserType, value: userType),
    ]);
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Get user email
  static Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  /// Get user type
  static Future<String?> getUserType() async {
    return await _storage.read(key: _keyUserType);
  }

  /// Save username
  static Future<void> saveUsername(String username) async {
    await _storage.write(key: _keyUsername, value: username);
  }

  /// Get username
  static Future<String?> getUsername() async {
    return await _storage.read(key: _keyUsername);
  }

  /// Check if user is logged in (has valid tokens)
  static Future<bool> isLoggedIn() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      final userId = await getUserId();

      // More strict checking: need all 3 values
      final hasTokens =
          accessToken != null &&
          accessToken.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty;

      return hasTokens;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  /// Clear all data (logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Enable/Disable biometric authentication
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  /// Check if biometric is enabled
  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }
}
