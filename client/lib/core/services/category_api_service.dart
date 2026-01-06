import 'package:dio/dio.dart';
import 'package:workradar/core/network/api_client.dart';
import 'package:workradar/core/network/api_exception.dart';
import 'package:workradar/core/services/task_api_service.dart';

/// Category API Service
class CategoryApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get all categories
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _apiClient.get('/categories');

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = response.data['categories'] ?? [];
        return categoriesJson
            .map((json) => CategoryModel.fromJson(json))
            .toList();
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get categories',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Create new category
  Future<CategoryModel> createCategory({
    required String name,
    required String color,
  }) async {
    try {
      final response = await _apiClient.post(
        '/categories',
        data: {'name': name, 'color': color},
      );

      if (response.statusCode == 201) {
        return CategoryModel.fromJson(response.data['category']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to create category',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Update category
  Future<CategoryModel> updateCategory({
    required String categoryId,
    String? name,
    String? color,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (color != null) data['color'] = color;

      final response = await _apiClient.put(
        '/categories/$categoryId',
        data: data,
      );

      if (response.statusCode == 200) {
        return CategoryModel.fromJson(response.data['category']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to update category',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Delete category
  Future<void> deleteCategory(String categoryId) async {
    try {
      final response = await _apiClient.delete('/categories/$categoryId');

      if (response.statusCode != 200) {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to delete category',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
