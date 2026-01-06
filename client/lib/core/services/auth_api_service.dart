import 'package:dio/dio.dart';
import 'package:workradar/core/network/api_client.dart';
import 'package:workradar/core/network/api_exception.dart';
import 'package:workradar/core/storage/secure_storage.dart';

/// Auth API Service
class AuthApiService {
  final ApiClient _apiClient = ApiClient();

  /// Register new user
  Future<AuthResponse> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {'email': email, 'username': username, 'password': password},
      );

      if (response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveAuthData(authResponse);
        return authResponse;
      }

      throw ApiException(
        message: response.data['error'] ?? 'Registration failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Login user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveAuthData(authResponse);
        return authResponse;
      }

      throw ApiException(
        message: response.data['error'] ?? 'Login failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Refresh access token
  Future<String> refreshToken() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        throw ApiException(message: 'No refresh token');
      }

      final response = await _apiClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        await SecureStorage.saveAccessToken(newAccessToken);
        return newAccessToken;
      }

      throw ApiException(
        message: 'Token refresh failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Logout user (blacklist tokens)
  Future<void> logout() async {
    try {
      final accessToken = await SecureStorage.getAccessToken();
      final refreshToken = await SecureStorage.getRefreshToken();

      await _apiClient.post(
        '/auth/logout',
        data: {'access_token': accessToken, 'refresh_token': refreshToken},
      );
    } catch (e) {
      // Ignore errors, proceed with clearing local storage
    } finally {
      await SecureStorage.clearAll();
    }
  }

  /// Forgot password
  Future<String> forgotPassword(String email) async {
    try {
      final response = await _apiClient.post(
        '/auth/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        return response.data['code'] ?? ''; // Dev only
      }

      throw ApiException(
        message: response.data['error'] ?? 'Request failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Reset password with verification code
  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/reset-password',
        data: {'code': code, 'new_password': newPassword},
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: response.data['error'] ?? 'Reset failed',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await SecureStorage.isLoggedIn();
  }

  /// Save auth data to secure storage
  Future<void> _saveAuthData(AuthResponse auth) async {
    await SecureStorage.saveAccessToken(auth.token);
    if (auth.refreshToken != null) {
      await SecureStorage.saveRefreshToken(auth.refreshToken!);
    }
    if (auth.user != null) {
      await SecureStorage.saveUserData(
        userId: auth.user!.id,
        email: auth.user!.email,
        userType: auth.user!.userType,
      );
    }
  }
}

/// Auth Response model
class AuthResponse {
  final String message;
  final String token;
  final String? refreshToken;
  final UserData? user;

  AuthResponse({
    required this.message,
    required this.token,
    this.refreshToken,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: json['message'] ?? '',
      token: json['token'] ?? '',
      refreshToken: json['refresh_token'],
      user: json['user'] != null ? UserData.fromJson(json['user']) : null,
    );
  }
}

/// User Data model
class UserData {
  final String id;
  final String email;
  final String username;
  final String? profilePicture;
  final String authProvider;
  final String userType;
  final DateTime? vipExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserData({
    required this.id,
    required this.email,
    required this.username,
    this.profilePicture,
    required this.authProvider,
    required this.userType,
    this.vipExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      profilePicture: json['profile_picture'],
      authProvider: json['auth_provider'] ?? 'local',
      userType: json['user_type'] ?? 'regular',
      vipExpiresAt: json['vip_expires_at'] != null
          ? DateTime.parse(json['vip_expires_at'])
          : null,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  bool get isVip => userType == 'vip';
}
