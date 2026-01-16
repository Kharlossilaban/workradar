import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage wrapper untuk menyimpan data sensitif (encrypted)
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
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
    print('[SecureStorage] 💾 Saving access token (length: ${token.length})');
    await _storage.write(key: _keyAccessToken, value: token);
    print('[SecureStorage] ✅ Access token saved');
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  /// Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
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
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    final result = accessToken != null && refreshToken != null;
    print(
      '[SecureStorage] 🔍 isLoggedIn check: $result (accessToken: ${accessToken != null}, refreshToken: ${refreshToken != null})',
    );
    return result;
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
