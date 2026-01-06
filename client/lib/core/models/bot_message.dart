enum MessageType { payment, welcome, tip, alert, update }

class BotMessage {
  final String id;
  final String userId;
  final MessageType type;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  BotMessage({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  factory BotMessage.fromJson(Map<String, dynamic> json) {
    return BotMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: _parseType(json['type'] as String),
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': _typeToString(type),
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      if (metadata != null) 'metadata': metadata,
    };
  }

  BotMessage copyWith({
    String? id,
    String? userId,
    MessageType? type,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return BotMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  static MessageType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return MessageType.payment;
      case 'welcome':
        return MessageType.welcome;
      case 'tip':
        return MessageType.tip;
      case 'alert':
        return MessageType.alert;
      case 'update':
        return MessageType.update;
      default:
        return MessageType.update;
    }
  }

  static String _typeToString(MessageType type) {
    switch (type) {
      case MessageType.payment:
        return 'payment';
      case MessageType.welcome:
        return 'welcome';
      case MessageType.tip:
        return 'tip';
      case MessageType.alert:
        return 'alert';
      case MessageType.update:
        return 'update';
    }
  }

  // Get icon for message type
  String get iconName {
    switch (type) {
      case MessageType.payment:
        return 'wallet';
      case MessageType.welcome:
        return 'emoji_happy';
      case MessageType.tip:
        return 'lamp_on';
      case MessageType.alert:
        return 'warning_2';
      case MessageType.update:
        return 'info_circle';
    }
  }

  // Get color for message type
  String get colorHex {
    switch (type) {
      case MessageType.payment:
        return '#4CAF50'; // Green
      case MessageType.welcome:
        return '#FF9800'; // Orange
      case MessageType.tip:
        return '#2196F3'; // Blue
      case MessageType.alert:
        return '#F44336'; // Red
      case MessageType.update:
        return '#9C27B0'; // Purple
    }
  }
}
