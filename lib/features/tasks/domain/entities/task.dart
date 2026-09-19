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

  /// Sentinel distinguishing "argument omitted" from an explicit `null`.
  static const Object _unset = Object();

  /// Creates a copy of this task with the given fields replaced.
  ///
  /// Passing `description: null` explicitly **clears** the description;
  /// omitting it keeps the current value.
  Task copyWith({
    String? id,
    String? title,
    Object? description = _unset,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
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
          isCompleted == other.isCompleted &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    isCompleted,
    createdAt,
    updatedAt,
  );
}
