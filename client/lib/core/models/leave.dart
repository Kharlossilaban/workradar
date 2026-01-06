class Leave {
  final String id;
  final String userId;
  final DateTime date;
  final String reason;
  final bool isApproved; // For future approval workflow
  final DateTime createdAt;

  Leave({
    required this.id,
    required this.userId,
    required this.date,
    required this.reason,
    this.isApproved = true,
    required this.createdAt,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    return Leave(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      reason: json['reason'] as String,
      isApproved: json['is_approved'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'reason': reason,
      'is_approved': isApproved,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Leave copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? reason,
    bool? isApproved,
    DateTime? createdAt,
  }) {
    return Leave(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Leave && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
