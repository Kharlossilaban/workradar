import 'package:uuid/uuid.dart';

/// Chat message model for AI chat
class ChatMessage {
  final String id;
  final String userId;
  final String role; // 'user' or 'model'
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  /// Check if this is a user message
  bool get isUser => role == 'user';

  /// Check if this is an AI response
  bool get isAI => role == 'model';

  /// Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? const Uuid().v4(),
      userId: json['user_id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role': role,
      'content': content,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Create a copy with modifications
  ChatMessage copyWith({
    String? id,
    String? userId,
    String? role,
    String? content,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
