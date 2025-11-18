import 'package:flutter_starter/features/tasks/domain/entities/task.dart';

/// Task model (data layer) - extends entity
class TaskModel extends Task {
  /// Creates a [TaskModel] with the given [id], [title], [description],
  /// [isCompleted], [createdAt], and [updatedAt]
  const TaskModel({
    required super.id,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
    super.description,
    super.isCompleted,
  });

  /// Create TaskModel from JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Create TaskModel from entity
  factory TaskModel.fromEntity(Task task) {
    return TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      isCompleted: task.isCompleted,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
  }

  /// Convert TaskModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert TaskModel to entity (returns itself as it extends Task)
  Task toEntity() => this;
}
