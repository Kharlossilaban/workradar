import 'package:flutter/material.dart';

class Category {
  final String id;
  final String userId;
  final String name;
  final bool isDefault;
  final bool isHidden;
  final Color? color;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    this.isDefault = false,
    this.isHidden = false,
    this.color,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      isDefault: json['is_default'] as bool? ?? false,
      isHidden: json['is_hidden'] as bool? ?? false,
      color: json['color'] != null ? Color(json['color'] as int) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'is_default': isDefault,
      'is_hidden': isHidden,
      'color': color?.toARGB32(),
    };
  }

  Category copyWith({
    String? id,
    String? userId,
    String? name,
    bool? isDefault,
    bool? isHidden,
    Color? color,
  }) {
    return Category(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      isHidden: isHidden ?? this.isHidden,
      color: color ?? this.color,
    );
  }
}
