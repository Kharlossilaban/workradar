class Holiday {
  final String id;
  final String name;
  final DateTime date;
  final bool
  isNational; // National holidays (tanggal merah) vs Personal holidays
  final String? description;

  Holiday({
    required this.id,
    required this.name,
    required this.date,
    this.isNational = false,
    this.description,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      id: json['id'] as String,
      name: json['name'] as String,
      date: DateTime.parse(json['date'] as String),
      isNational: json['is_national'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'is_national': isNational,
      if (description != null) 'description': description,
    };
  }

  Holiday copyWith({
    String? id,
    String? name,
    DateTime? date,
    bool? isNational,
    String? description,
  }) {
    return Holiday(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      isNational: isNational ?? this.isNational,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Holiday && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
