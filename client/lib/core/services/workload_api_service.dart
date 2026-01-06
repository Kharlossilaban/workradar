import 'package:dio/dio.dart';
import 'package:workradar/core/network/api_client.dart';
import 'package:workradar/core/network/api_exception.dart';

/// Workload API Service
class WorkloadApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get workload data for chart
  Future<WorkloadResponse> getWorkload({
    String period = 'daily', // 'daily', 'weekly', 'monthly'
  }) async {
    try {
      final response = await _apiClient.get(
        '/workload',
        queryParameters: {'period': period},
      );

      if (response.statusCode == 200) {
        return WorkloadResponse.fromJson(response.data);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get workload',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get daily workload (7 days)
  Future<WorkloadResponse> getDailyWorkload() async {
    return getWorkload(period: 'daily');
  }

  /// Get weekly workload (4 weeks)
  Future<WorkloadResponse> getWeeklyWorkload() async {
    return getWorkload(period: 'weekly');
  }

  /// Get monthly workload (12 months)
  Future<WorkloadResponse> getMonthlyWorkload() async {
    return getWorkload(period: 'monthly');
  }
}

/// Workload Response
class WorkloadResponse {
  final String period;
  final List<WorkloadData> data;

  WorkloadResponse({required this.period, required this.data});

  factory WorkloadResponse.fromJson(Map<String, dynamic> json) {
    return WorkloadResponse(
      period: json['period'] ?? 'daily',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((d) => WorkloadData.fromJson(d))
              .toList() ??
          [],
    );
  }

  /// Get max count for chart scaling
  int get maxCount {
    if (data.isEmpty) return 1;
    return data.map((d) => d.count).reduce((a, b) => a > b ? a : b);
  }

  /// Get total count
  int get totalCount {
    return data.map((d) => d.count).fold(0, (a, b) => a + b);
  }
}

/// Workload Data point
class WorkloadData {
  final String label;
  final int count;

  WorkloadData({required this.label, required this.count});

  factory WorkloadData.fromJson(Map<String, dynamic> json) {
    return WorkloadData(label: json['label'] ?? '', count: json['count'] ?? 0);
  }
}
