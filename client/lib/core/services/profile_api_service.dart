import 'package:dio/dio.dart';
import 'package:workradar/core/network/api_client.dart';
import 'package:workradar/core/network/api_exception.dart';
import 'package:workradar/core/services/auth_api_service.dart';
import 'package:workradar/core/services/task_api_service.dart';

/// Profile API Service
class ProfileApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get full profile with stats and categories
  Future<ProfileResponse> getProfile() async {
    try {
      final response = await _apiClient.get('/profile');

      if (response.statusCode == 200) {
        return ProfileResponse.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get profile',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get stats only
  Future<UserStats> getStats() async {
    try {
      final response = await _apiClient.get('/profile/stats');

      if (response.statusCode == 200) {
        return UserStats.fromJson(response.data['stats']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get stats',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Update profile
  Future<UserData> updateProfile({
    String? username,
    String? profilePicture,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (profilePicture != null) data['profile_picture'] = profilePicture;

      final response = await _apiClient.put('/profile', data: data);

      if (response.statusCode == 200) {
        return UserData.fromJson(response.data['user']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to update profile',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Change password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '/profile/change-password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to change password',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Update work hours configuration
  Future<void> updateWorkHours(Map<String, dynamic> workDays) async {
    try {
      final response = await _apiClient.put(
        '/profile/work-hours',
        data: {'work_days': workDays},
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to update work hours',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get work hours configuration
  Future<Map<String, dynamic>> getWorkHours() async {
    try {
      final response = await _apiClient.get('/profile/work-hours');

      if (response.statusCode == 200) {
        return response.data['work_days'] as Map<String, dynamic>? ?? {};
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get work hours',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Profile Response with stats
class ProfileResponse {
  final UserData user;
  final UserStats stats;
  final List<CategoryModel> categories;

  ProfileResponse({
    required this.user,
    required this.stats,
    required this.categories,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      user: UserData.fromJson(json['user']),
      stats: UserStats.fromJson(json['stats']),
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((c) => CategoryModel.fromJson(c))
              .toList() ??
          [],
    );
  }
}

/// User Stats model
class UserStats {
  final int totalTasks;
  final int completedTasks;
  final double completionRate;
  final int todayTasks;
  final int pendingTasks;

  UserStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.completionRate,
    required this.todayTasks,
    required this.pendingTasks,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalTasks: json['total_tasks'] ?? 0,
      completedTasks: json['completed_tasks'] ?? 0,
      completionRate: (json['completion_rate'] ?? 0.0).toDouble(),
      todayTasks: json['today_tasks'] ?? 0,
      pendingTasks: json['pending_tasks'] ?? 0,
    );
  }
}
