import 'package:flutter/foundation.dart';

/// Task entity (domain layer)
@immutable
class Task {
  /// Creates a [Task] with the given [id], [title], [description],
  /// [isCompleted], and optional [createdAt] and [updatedAt]
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isCompleted = false,
  });

  /// Unique task identifier
  final String id;

  /// Task title
  final String title;

  /// Task description (optional)
  final String? description;

  /// Whether the task is completed
  final bool isCompleted;

  /// Task creation timestamp
  final DateTime createdAt;

  /// Task last update timestamp
  final DateTime updatedAt;

  /// Creates a copy of this task with the given fields replaced
  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      isCompleted.hashCode;
}
