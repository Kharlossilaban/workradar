import 'package:dio/dio.dart';
import 'package:workradar/core/network/api_client.dart';
import 'package:workradar/core/network/api_exception.dart';
import 'package:workradar/core/services/task_api_service.dart';

/// Calendar API Service
class CalendarApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get today's tasks
  Future<CalendarResponse> getTodayTasks() async {
    try {
      final response = await _apiClient.get('/calendar/today');

      if (response.statusCode == 200) {
        return CalendarResponse.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get today tasks',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get this week's tasks
  Future<CalendarResponse> getWeekTasks() async {
    try {
      final response = await _apiClient.get('/calendar/week');

      if (response.statusCode == 200) {
        return CalendarResponse.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get week tasks',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get this month's tasks
  Future<CalendarResponse> getMonthTasks() async {
    try {
      final response = await _apiClient.get('/calendar/month');

      if (response.statusCode == 200) {
        return CalendarResponse.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get month tasks',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get tasks by date range
  Future<CalendarResponse> getTasksByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        '/calendar/range',
        queryParameters: {
          'start': _formatDate(startDate),
          'end': _formatDate(endDate),
        },
      );

      if (response.statusCode == 200) {
        return CalendarResponse.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get tasks',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Calendar Response
class CalendarResponse {
  final String date;
  final List<TaskModel> tasks;
  final int count;

  CalendarResponse({
    required this.date,
    required this.tasks,
    required this.count,
  });

  factory CalendarResponse.fromJson(Map<String, dynamic> json) {
    return CalendarResponse(
      date: json['date'] ?? '',
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((t) => TaskModel.fromJson(t))
              .toList() ??
          [],
      count: json['count'] ?? 0,
    );
  }
}
