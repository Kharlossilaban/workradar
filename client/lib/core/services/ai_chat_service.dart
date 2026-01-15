import 'package:dio/dio.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../models/chat_message.dart';

/// AI Chat API Service
class AIChatService {
  final ApiClient _apiClient = ApiClient();

  /// Send message to AI and get response
  Future<String> sendMessage(String message) async {
    try {
      final response = await _apiClient.post(
        '/ai/chat',
        data: {'message': message},
      );

      if (response.statusCode == 200) {
        return response.data['response'] ?? '';
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get AI response',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get chat history
  Future<List<ChatMessage>> getChatHistory() async {
    try {
      final response = await _apiClient.get('/ai/history');

      if (response.statusCode == 200) {
        final List<dynamic> messagesJson = response.data['messages'] ?? [];
        return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
      }

      throw ApiException(
        message: response.data['error'] ?? 'Failed to get chat history',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Clear chat history
  Future<void> clearHistory() async {
    try {
      final response = await _apiClient.delete('/ai/history');

      if (response.statusCode != 200) {
        throw ApiException(
          message: response.data['error'] ?? 'Failed to clear history',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
