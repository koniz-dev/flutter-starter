import 'package:flutter_starter/core/utils/date_formatter.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';

/// Task model (data layer) - extends entity
///
/// ## Timestamp format
///
/// `created_at` and `updated_at` are written by [toJson] through
/// [DateFormatter.formatIso8601], so they always carry the `Z` designator and
/// always describe an absolute instant:
///
/// ```json
/// {"created_at": "2024-01-15T07:30:45.000Z"}
/// ```
///
/// Before this, [toJson] called `DateTime.toIso8601String()` on a **local**
/// [DateTime], which emits neither `Z` nor a numeric offset
/// (`'2024-01-15T14:30:45.000'`). That string means nothing without knowing
/// the device's zone: every ISO-8601 consumer outside Dart reads a missing
/// designator as UTC, so a task created at 14:30 on a UTC+7 phone was
/// recorded as 07:30, and two devices in different zones could not order each
/// other's tasks.
///
/// ## Legacy rows: read as local, no migration
///
/// [TaskModel.fromJson] accepts both shapes. A string with a designator is
/// read as the instant it names. An offset-less legacy string is read as
/// **local wall clock**, exactly as `DateTime.parse` and therefore the
/// previous implementation did, so no row already on disk shifts when this
/// version is installed.
///
/// No storage migration ships with this change, deliberately. A migration
/// could not improve on the read path: the only information a legacy string
/// carries is wall-clock digits, so converting it at first launch would still
/// have to assume the device's *current* zone - the same assumption the read
/// path makes, reached at the same moment. The offset that was in force when
/// the row was written was never recorded and is not recoverable by any
/// reader. A migration would therefore buy no accuracy while adding a boot
/// path that can fail (a failed startup migration reaches `StartupFailureApp`
/// since koniz-dev/flutter-starter#101).
///
/// Legacy rows drain on their own instead. `TasksLocalDataSource` stores the
/// whole list under one key and rewrites all of it on any mutation, so the
/// first task a user adds, edits, toggles, or deletes re-encodes every row in
/// the `Z` form.
///
/// The residual exposure is unchanged by this decision and unavoidable: a
/// legacy row read after the device has changed zone is off by the difference,
/// because the row never said which zone it meant.
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
  ///
  /// Throws a [FormatException] when `created_at` or `updated_at` is absent,
  /// is not a string, or does not parse - including an out-of-range calendar
  /// date such as `'2024-02-30T00:00:00Z'`, which `DateTime.parse` would
  /// silently roll over to 1 March.
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: _parseTimestamp(json, 'created_at'),
      updatedAt: _parseTimestamp(json, 'updated_at'),
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

  /// Read [key] from [json] as an ISO-8601 timestamp.
  ///
  /// The result is returned in **local** time, which is the contract
  /// [Task.createdAt] has always had and what `task_detail_screen.dart`
  /// formats for display. The instant is the one the string named; only the
  /// zone flag differs from [DateFormatter.parseIso8601]'s UTC result.
  static DateTime _parseTimestamp(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! String) {
      throw FormatException(
        'Task JSON field "$key" must be an ISO-8601 string, got '
        '${raw.runtimeType}',
      );
    }

    final parsed = DateFormatter.parseIso8601(raw);
    if (parsed == null) {
      throw FormatException(
        'Task JSON field "$key" is not a valid '
        'ISO-8601 timestamp',
        raw,
      );
    }

    return parsed.toLocal();
  }

  /// Convert TaskModel to JSON
  ///
  /// Timestamps are emitted in UTC with the `Z` designator, so the instant
  /// survives leaving the device. See the class doc.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'created_at': DateFormatter.formatIso8601(createdAt),
      'updated_at': DateFormatter.formatIso8601(updatedAt),
    };
  }

  /// Convert TaskModel to entity (returns itself as it extends Task)
  Task toEntity() => this;
}
