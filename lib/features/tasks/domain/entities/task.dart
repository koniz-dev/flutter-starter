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

  /// Returns a copy of this task whose [updatedAt] is [at], defaulting to now.
  ///
  /// Every modification of a task restamps [updatedAt]; that is an invariant of
  /// the entity, so the stamp is minted here rather than by whichever caller
  /// happens to be performing the modification. Before
  /// koniz-dev/flutter-starter#180 three callers minted their own - the update
  /// use case, `TasksRepositoryImpl.toggleTaskCompletion` in `data/`, and
  /// `task_detail_screen.dart` in widget code - so the slice taught three
  /// different answers about where the rule lives.
  Task touch({DateTime? at}) => copyWith(updatedAt: at ?? DateTime.now());

  /// Returns a copy of this task with [isCompleted] flipped and [updatedAt]
  /// restamped through [touch].
  ///
  /// Completing a task is a modification like any other, so both halves of the
  /// rule belong together and in `domain/`. `TasksRepositoryImpl` applies this
  /// inside its atomic mutation rather than restating it.
  Task toggleCompletion({DateTime? at}) =>
      copyWith(isCompleted: !isCompleted).touch(at: at);

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
