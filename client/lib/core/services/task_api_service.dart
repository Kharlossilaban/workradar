import 'package:dio/dio.dart';
import 'package:workradar/core/network/api_client.dart';
import 'package:workradar/core/network/api_exception.dart';

/// Task API Service
class TaskApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get all tasks (optional filter by category)
  Future<List<TaskModel>> getTasks({String? categoryId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }

      final response = await _apiClient.get(
        '/tasks',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> tasksJson = response.data['tasks'] ?? [];
        return tasksJson.map((json) => TaskModel.fromJson(json)).toList();
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get tasks',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get task by ID
  Future<TaskModel> getTaskById(String taskId) async {
    try {
      final response = await _apiClient.get('/tasks/$taskId');

      if (response.statusCode == 200) {
        return TaskModel.fromJson(response.data['task']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Task not found',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Create new task
  Future<TaskModel> createTask({
    required String title,
    String? description,
    String? categoryId,
    DateTime? deadline,
    int? reminderMinutes,
    String repeatType = 'none',
    int repeatInterval = 1,
    DateTime? repeatEndDate,
  }) async {
    try {
      final data = <String, dynamic>{'title': title};

      if (description != null) data['description'] = description;
      if (categoryId != null) data['category_id'] = categoryId;
      if (deadline != null) {
        data['deadline'] = deadline.toUtc().toIso8601String();
      }
      if (reminderMinutes != null) data['reminder_minutes'] = reminderMinutes;
      if (repeatType != 'none') {
        data['repeat_type'] = repeatType;
        data['repeat_interval'] = repeatInterval;
        if (repeatEndDate != null) {
          data['repeat_end_date'] = repeatEndDate.toUtc().toIso8601String();
        }
      }

      final response = await _apiClient.post('/tasks', data: data);

      if (response.statusCode == 201) {
        return TaskModel.fromJson(response.data['task']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to create task',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Update task
  Future<TaskModel> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? categoryId,
    DateTime? deadline,
    int? reminderMinutes,
    String? repeatType,
    int? repeatInterval,
    DateTime? repeatEndDate,
    bool? isCompleted,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (categoryId != null) data['category_id'] = categoryId;
      if (deadline != null) {
        data['deadline'] = deadline.toUtc().toIso8601String();
      }
      if (reminderMinutes != null) data['reminder_minutes'] = reminderMinutes;
      if (repeatType != null) data['repeat_type'] = repeatType;
      if (repeatInterval != null) data['repeat_interval'] = repeatInterval;
      if (repeatEndDate != null) {
        data['repeat_end_date'] = repeatEndDate.toUtc().toIso8601String();
      }
      if (isCompleted != null) data['is_completed'] = isCompleted;

      final response = await _apiClient.put('/tasks/$taskId', data: data);

      if (response.statusCode == 200) {
        return TaskModel.fromJson(response.data['task']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to update task',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Delete task
  Future<void> deleteTask(String taskId) async {
    try {
      final response = await _apiClient.delete('/tasks/$taskId');

      if (response.statusCode != 200) {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to delete task',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Toggle task completion
  Future<TaskModel> toggleComplete(String taskId) async {
    try {
      final response = await _apiClient.patch('/tasks/$taskId/toggle');

      if (response.statusCode == 200) {
        return TaskModel.fromJson(response.data['task']);
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to toggle task',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Task Model
class TaskModel {
  final String id;
  final String userId;
  final String? categoryId;
  final String title;
  final String? description;
  final DateTime? deadline;
  final int? reminderMinutes;
  final String repeatType;
  final int repeatInterval;
  final DateTime? repeatEndDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final CategoryModel? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.title,
    this.description,
    this.deadline,
    this.reminderMinutes,
    this.repeatType = 'none',
    this.repeatInterval = 1,
    this.repeatEndDate,
    this.isCompleted = false,
    this.completedAt,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      categoryId: json['category_id'],
      title: json['title'] ?? '',
      description: json['description'],
      // Convert UTC time from server to local timezone
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline']).toLocal()
          : null,
      reminderMinutes: json['reminder_minutes'],
      repeatType: json['repeat_type'] ?? 'none',
      repeatInterval: json['repeat_interval'] ?? 1,
      repeatEndDate: json['repeat_end_date'] != null
          ? DateTime.parse(json['repeat_end_date']).toLocal()
          : null,
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at']).toLocal()
          : null,
      category: json['category'] != null
          ? CategoryModel.fromJson(json['category'])
          : null,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ).toLocal(),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'deadline': deadline?.toIso8601String(),
      'reminder_minutes': reminderMinutes,
      'repeat_type': repeatType,
      'repeat_interval': repeatInterval,
      'repeat_end_date': repeatEndDate?.toIso8601String(),
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TaskModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? title,
    String? description,
    DateTime? deadline,
    int? reminderMinutes,
    String? repeatType,
    int? repeatInterval,
    DateTime? repeatEndDate,
    bool? isCompleted,
    DateTime? completedAt,
    CategoryModel? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Category Model (used in Task)
class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String color;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      color: json['color'] ?? '#6C5CE7',
      isDefault: json['is_default'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color': color,
      'is_default': isDefault,
    };
  }
}
