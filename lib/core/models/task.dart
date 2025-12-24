enum RepeatType { none, hourly, daily, weekly, monthly }

class Task {
  final String id;
  final String userId;
  final String? categoryId;
  final String categoryName;
  final String title;
  final DateTime? deadline;
  final int? reminderMinutes;
  final RepeatType repeatType;
  final int repeatInterval;
  final DateTime? repeatEndDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.userId,
    this.categoryId,
    this.categoryName = 'Kerja',
    required this.title,
    this.deadline,
    this.reminderMinutes,
    this.repeatType = RepeatType.none,
    this.repeatInterval = 1,
    this.repeatEndDate,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasReminder => reminderMinutes != null;
  bool get hasRepeat => repeatType != RepeatType.none;
  bool get hasDeadline => deadline != null;

  String get repeatTypeString {
    switch (repeatType) {
      case RepeatType.hourly:
        return 'Jam';
      case RepeatType.daily:
        return 'Harian';
      case RepeatType.weekly:
        return 'Mingguan';
      case RepeatType.monthly:
        return 'Bulanan';
      default:
        return 'Tidak';
    }
  }

  String get reminderString {
    if (reminderMinutes == null) return 'Tidak ada';
    return '$reminderMinutes menit sebelumnya';
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String? ?? 'Kerja',
      title: json['title'] as String,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      reminderMinutes: json['reminder_minutes'] as int?,
      repeatType: _parseRepeatType(json['repeat_type'] as String?),
      repeatInterval: json['repeat_interval'] as int? ?? 1,
      repeatEndDate: json['repeat_end_date'] != null
          ? DateTime.parse(json['repeat_end_date'] as String)
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static RepeatType _parseRepeatType(String? type) {
    switch (type) {
      case 'hourly':
        return RepeatType.hourly;
      case 'daily':
        return RepeatType.daily;
      case 'weekly':
        return RepeatType.weekly;
      case 'monthly':
        return RepeatType.monthly;
      default:
        return RepeatType.none;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'category_name': categoryName,
      'title': title,
      'deadline': deadline?.toIso8601String(),
      'reminder_minutes': reminderMinutes,
      'repeat_type': repeatType.name,
      'repeat_interval': repeatInterval,
      'repeat_end_date': repeatEndDate?.toIso8601String(),
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? categoryName,
    String? title,
    DateTime? deadline,
    int? reminderMinutes,
    RepeatType? repeatType,
    int? repeatInterval,
    DateTime? repeatEndDate,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      title: title ?? this.title,
      deadline: deadline ?? this.deadline,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
