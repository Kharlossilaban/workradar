import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/environment.dart';

/// MFAApiService handles Multi-Factor Authentication API calls.
///
/// Endpoints:
/// - GET /api/auth/mfa/status - Get MFA status
/// - POST /api/auth/mfa/enable - Generate MFA secret & QR code
/// - POST /api/auth/mfa/verify - Verify and enable MFA
/// - POST /api/auth/mfa/disable - Disable MFA
/// - POST /api/auth/mfa/verify-login - Verify MFA during login
class MFAApiService {
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get current MFA status for the user
  Future<MFAStatusResponse> getMFAStatus() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/auth/mfa/status'),
      headers: _headers(token),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return MFAStatusResponse(
        mfaEnabled: data['mfa_enabled'] ?? false,
        hasSecret: data['has_secret'] ?? false,
      );
    }

    throw Exception(data['error'] ?? 'Failed to get MFA status');
  }

  /// Enable MFA - generates secret and returns QR code URL
  Future<MFASetupResponse> enableMFA() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/auth/mfa/enable'),
      headers: _headers(token),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return MFASetupResponse(
        secret: data['secret'],
        qrCodeUrl: data['qr_code_url'],
        manualCode: data['manual_code'],
        instructions: List<String>.from(data['instructions'] ?? []),
      );
    }

    throw Exception(data['error'] ?? 'Failed to enable MFA');
  }

  /// Verify MFA code and complete setup
  Future<bool> verifyMFA(String code) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/auth/mfa/verify'),
      headers: _headers(token),
      body: jsonEncode({'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['mfa_enabled'] ?? false;
    }

    throw Exception(data['error'] ?? 'Invalid verification code');
  }

  /// Disable MFA (requires current MFA code for security)
  Future<bool> disableMFA(String code) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/auth/mfa/disable'),
      headers: _headers(token),
      body: jsonEncode({'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return !(data['mfa_enabled'] ?? true);
    }

    throw Exception(data['error'] ?? 'Failed to disable MFA');
  }

  /// Verify MFA code during login
  Future<MFALoginResponse> verifyMFALogin(String userId, String code) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/auth/mfa/verify-login'),
      headers: _headers(null),
      body: jsonEncode({'user_id': userId, 'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return MFALoginResponse(
        verified: data['verified'] ?? false,
        message: data['message'],
      );
    }

    throw Exception(data['error'] ?? 'MFA verification failed');
  }
}

/// Response model for MFA status
class MFAStatusResponse {
  final bool mfaEnabled;
  final bool hasSecret;

  MFAStatusResponse({required this.mfaEnabled, required this.hasSecret});
}

/// Response model for MFA setup
class MFASetupResponse {
  final String secret;
  final String qrCodeUrl;
  final String manualCode;
  final List<String> instructions;

  MFASetupResponse({
    required this.secret,
    required this.qrCodeUrl,
    required this.manualCode,
    required this.instructions,
  });
}

/// Response model for MFA login verification
class MFALoginResponse {
  final bool verified;
  final String? message;

  MFALoginResponse({required this.verified, this.message});
}
