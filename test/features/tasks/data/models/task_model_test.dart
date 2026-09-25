import 'dart:convert';

import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_fixtures.dart';

void main() {
  group('TaskModel', () {
    test('should create TaskModel from JSON', () {
      // Arrange
      final json = createTaskJson(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromJson(json);

      // Assert
      expect(taskModel.id, 'task-1');
      expect(taskModel.title, 'Test Task');
      expect(taskModel.description, 'Test Description');
      expect(taskModel.isCompleted, isTrue);
      expect(taskModel.createdAt, isA<DateTime>());
      expect(taskModel.updatedAt, isA<DateTime>());
    });

    test('should create TaskModel from JSON without description', () {
      // Arrange
      final json = createTaskJson(id: 'task-1');

      // Act
      final taskModel = TaskModel.fromJson(json);

      // Assert
      expect(taskModel.id, 'task-1');
      expect(taskModel.title, 'Test Task');
      expect(taskModel.description, isNull);
      expect(taskModel.isCompleted, isFalse);
    });

    test('should convert TaskModel to JSON', () {
      // Arrange
      final taskModel = createTaskModel(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final json = taskModel.toJson();

      // Assert
      expect(json['id'], 'task-1');
      expect(json['title'], 'Test Task');
      expect(json['description'], 'Test Description');
      expect(json['is_completed'], isTrue);
      expect(json['created_at'], isA<String>());
      expect(json['updated_at'], isA<String>());
    });

    test('should convert TaskModel to JSON without description', () {
      // Arrange
      final taskModel = createTaskModel(id: 'task-1');

      // Act
      final json = taskModel.toJson();

      // Assert
      expect(json['id'], 'task-1');
      expect(json['title'], 'Test Task');
      expect(json['description'], isNull);
      expect(json['is_completed'], isFalse);
    });

    test('should create TaskModel from entity', () {
      // Arrange
      final task = createTask(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromEntity(task);

      // Assert
      expect(taskModel.id, task.id);
      expect(taskModel.title, task.title);
      expect(taskModel.description, task.description);
      expect(taskModel.isCompleted, task.isCompleted);
      expect(taskModel.createdAt, task.createdAt);
      expect(taskModel.updatedAt, task.updatedAt);
    });

    test('should convert TaskModel to entity', () {
      // Arrange
      final taskModel = createTaskModel(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final entity = taskModel.toEntity();

      // Assert
      expect(entity.id, taskModel.id);
      expect(entity.title, taskModel.title);
      expect(entity.description, taskModel.description);
      expect(entity.isCompleted, taskModel.isCompleted);
      expect(entity.createdAt, taskModel.createdAt);
      expect(entity.updatedAt, taskModel.updatedAt);
    });

    test('should handle round-trip conversion (JSON -> Model -> JSON)', () {
      // Arrange
      final originalJson = createTaskJson(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromJson(originalJson);
      final convertedJson = taskModel.toJson();

      // Assert
      expect(convertedJson['id'], originalJson['id']);
      expect(convertedJson['title'], originalJson['title']);
      expect(convertedJson['description'], originalJson['description']);
      expect(convertedJson['is_completed'], originalJson['is_completed']);
    });

    test('should handle round-trip conversion (Entity -> Model -> Entity)', () {
      // Arrange
      final originalTask = createTask(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromEntity(originalTask);
      final convertedTask = taskModel.toEntity();

      // Assert
      expect(convertedTask.id, originalTask.id);
      expect(convertedTask.title, originalTask.title);
      expect(convertedTask.description, originalTask.description);
      expect(convertedTask.isCompleted, originalTask.isCompleted);
      expect(convertedTask.createdAt, originalTask.createdAt);
      expect(convertedTask.updatedAt, originalTask.updatedAt);
    });

    group('Edge cases', () {
      test('should handle JSON with null is_completed as false', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'description': null,
          'is_completed': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.isCompleted, isFalse);
      });

      test('should handle JSON with missing is_completed field', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.isCompleted, isFalse);
      });

      test('should handle JSON with empty string description', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'description': '',
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.description, '');
      });

      test('should preserve all fields in toJson', () {
        // Arrange
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          description: 'Test Description',
          isCompleted: true,
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final json = taskModel.toJson();

        // Assert
        expect(json['id'], 'task-1');
        expect(json['title'], 'Test Task');
        expect(json['description'], 'Test Description');
        expect(json['is_completed'], isTrue);
        // Timestamps are written in UTC with the `Z` designator, so the
        // expected text depends on the host zone - hence the computed
        // expectation rather than a literal. See the 'Timezone-safe
        // timestamps' group below.
        expect(json['created_at'], DateTime(2023).toUtc().toIso8601String());
        expect(
          json['updated_at'],
          DateTime(2023, 1, 2).toUtc().toIso8601String(),
        );
      });

      test('should handle very long title and description', () {
        // Arrange
        final longTitle = 'A' * 1000;
        final longDescription = 'B' * 2000;
        final taskModel = TaskModel(
          id: 'task-1',
          title: longTitle,
          description: longDescription,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.title, longTitle);
        expect(converted.description, longDescription);
      });

      test('should handle special characters in title and description', () {
        // Arrange
        const specialTitle =
            'Task with special chars: '
            r'!@#$%^&*()_+-=[]{}|;:,.<>?';
        const specialDescription = 'Description with unicode: 你好世界 🌍';
        final taskModel = TaskModel(
          id: 'task-1',
          title: specialTitle,
          description: specialDescription,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.title, specialTitle);
        expect(converted.description, specialDescription);
      });

      test('should handle ISO8601 timestamp variations', () {
        // Arrange
        final timestamps = [
          '2023-01-01T00:00:00.000Z',
          '2023-01-01T00:00:00Z',
          '2023-01-01T00:00:00.123456Z',
        ];

        for (final timestamp in timestamps) {
          final json = {
            'id': 'task-1',
            'title': 'Test Task',
            'created_at': timestamp,
            'updated_at': timestamp,
          };

          // Act & Assert
          expect(() => TaskModel.fromJson(json), returnsNormally);
        }
      });

      test('should handle task with same createdAt and updatedAt', () {
        // Arrange
        final now = DateTime.now();
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: now,
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.createdAt, now);
        expect(converted.updatedAt, now);
      });

      test('should handle task with updatedAt before createdAt', () {
        // Arrange
        final createdAt = DateTime(2023, 1, 2);
        final updatedAt = DateTime(2023);
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.createdAt, createdAt);
        expect(converted.updatedAt, updatedAt);
      });

      test('should handle fromEntity with all fields', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          description: 'Test Description',
          isCompleted: true,
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final taskModel = TaskModel.fromEntity(task);

        // Assert
        expect(taskModel.id, task.id);
        expect(taskModel.title, task.title);
        expect(taskModel.description, task.description);
        expect(taskModel.isCompleted, task.isCompleted);
        expect(taskModel.createdAt, task.createdAt);
        expect(taskModel.updatedAt, task.updatedAt);
      });

      test('should handle fromEntity with null description', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final taskModel = TaskModel.fromEntity(task);

        // Assert
        expect(taskModel.description, isNull);
      });

      test('should handle toEntity returns same instance', () {
        // Arrange
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final entity = taskModel.toEntity();

        // Assert
        expect(entity, same(taskModel));
        expect(entity, isA<Task>());
      });

      test('should handle JSON with false is_completed explicitly', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.isCompleted, isFalse);
      });

      test('should handle toJson with null description', () {
        // Arrange
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final json = taskModel.toJson();

        // Assert
        expect(json['description'], isNull);
      });
    });

    // Regression cover for koniz-dev/flutter-starter#146: toJson() used to
    // call toIso8601String() on a local DateTime, writing no `Z` and no
    // numeric offset, so the stored instant depended on the reader's zone.
    //
    // These assertions are deliberately host-timezone-agnostic so they hold
    // on a UTC CI runner as well as on a developer machine. The one that
    // reads the host offset ('toJson converts the wall clock...') is trivially
    // true at UTC+00:00 and is the load-bearing one elsewhere; run the file
    // under `TZ=Asia/Bangkok` to exercise it.
    group('Timezone-safe timestamps', () {
      Map<String, dynamic> jsonWith(String createdAt, String updatedAt) => {
        'id': 'task-1',
        'title': 'Test Task',
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

      TaskModel modelWith(DateTime createdAt, DateTime updatedAt) => TaskModel(
        id: 'task-1',
        title: 'Test Task',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      test('toJson writes a designator for a local DateTime', () {
        // Arrange
        final model = modelWith(
          DateTime(2024, 1, 15, 14, 30, 45),
          DateTime(2024, 1, 16, 9, 5),
        );

        // Act - through a real encode/decode, which is what reaches storage.
        final decoded =
            jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;

        // Assert
        expect(decoded['created_at'], endsWith('Z'));
        expect(decoded['updated_at'], endsWith('Z'));
      });

      test('toJson writes a designator for a UTC DateTime', () {
        // Arrange
        final model = modelWith(
          DateTime.utc(2024, 1, 15, 7, 30, 45),
          DateTime.utc(2024, 1, 16, 2, 5),
        );

        // Act
        final decoded =
            jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;

        // Assert
        expect(decoded['created_at'], endsWith('Z'));
        expect(decoded['updated_at'], endsWith('Z'));
      });

      test('toJson converts the wall clock by the host UTC offset', () {
        // Arrange
        final local = DateTime(2024, 1, 15, 14, 30, 45);

        // Act
        final written = DateTime.parse(
          modelWith(local, local).toJson()['created_at']! as String,
        );

        // Assert - the digits written are the UTC ones, not the local ones.
        // At UTC+07:00 that is 07:30:45Z for a 14:30:45 local timestamp.
        expect(written.isUtc, isTrue);
        expect(
          written.difference(DateTime.utc(2024, 1, 15, 14, 30, 45)),
          -local.timeZoneOffset,
          reason: 'host offset is ${local.timeZoneOffset}; written=$written',
        );
      });

      test('a round trip preserves the instant', () {
        // Arrange
        final originals = <DateTime>[
          DateTime(2024, 1, 15, 14, 30, 45),
          DateTime.utc(2024, 1, 15, 7, 30, 45),
          DateTime(2024, 6, 30, 23, 59, 59, 999),
          DateTime.now(),
        ];

        for (final original in originals) {
          // Act
          final restored = TaskModel.fromJson(
            modelWith(original, original).toJson(),
          );

          // Assert
          expect(
            restored.createdAt.isAtSameMomentAs(original),
            isTrue,
            reason:
                '$original round-tripped to ${restored.createdAt} '
                'at offset ${original.timeZoneOffset}',
          );
          expect(restored.updatedAt.isAtSameMomentAs(original), isTrue);
        }
      });

      test('a stored Z timestamp names one instant in every zone', () {
        // Arrange - a row written by any device, read by any other.
        final json = jsonWith(
          '2024-01-15T07:30:45.000Z',
          '2024-01-15T07:30:45.000Z',
        );

        // Act
        final restored = TaskModel.fromJson(json);

        // Assert - independent of the host zone, unlike the legacy shape.
        expect(
          restored.createdAt.toUtc(),
          DateTime.utc(2024, 1, 15, 7, 30, 45),
        );
        expect(
          restored.updatedAt.toUtc(),
          DateTime.utc(2024, 1, 15, 7, 30, 45),
        );
      });

      test('a stored numeric offset is honoured', () {
        // Arrange
        final json = jsonWith(
          '2024-01-15T14:30:45.000+07:00',
          '2024-01-15T14:30:45.000+07:00',
        );

        // Act
        final restored = TaskModel.fromJson(json);

        // Assert
        expect(
          restored.createdAt.toUtc(),
          DateTime.utc(2024, 1, 15, 7, 30, 45),
        );
      });

      test('a legacy offset-less row is read as local wall clock', () {
        // Arrange - the shape every row written before #146 has on disk.
        final json = jsonWith(
          '2026-09-19T14:30:00.000',
          '2026-09-19T14:30:00.000',
        );

        // Act
        final restored = TaskModel.fromJson(json);

        // Assert - identical to what the old DateTime.parse call produced,
        // so no row already on disk shifts. No migration converts these.
        expect(restored.createdAt, DateTime(2026, 9, 19, 14, 30));
        expect(restored.createdAt.isUtc, isFalse);
        expect(
          restored.createdAt.isAtSameMomentAs(
            DateTime.parse('2026-09-19T14:30:00.000'),
          ),
          isTrue,
        );
      });

      test('a legacy row gains a designator when it is next written', () {
        // Arrange
        final legacy = jsonWith(
          '2026-09-19T14:30:00.000',
          '2026-09-19T14:30:00.000',
        );

        // Act - the data source rewrites the whole list on any mutation,
        // which is how legacy rows drain without a migration.
        final rewritten = TaskModel.fromJson(legacy).toJson();

        // Assert
        expect(rewritten['created_at'], endsWith('Z'));
        expect(
          DateTime.parse(
            rewritten['created_at']! as String,
          ).isAtSameMomentAs(DateTime(2026, 9, 19, 14, 30)),
          isTrue,
        );
      });

      test('an out-of-range calendar date is rejected, not rolled over', () {
        // Arrange - DateTime.parse silently answers 1 March for this.
        expect(DateTime.parse('2024-02-30T00:00:00Z').month, 3);
        expect(DateTime.parse('2024-02-30T00:00:00Z').day, 1);

        // Act & Assert
        expect(
          () => TaskModel.fromJson(
            jsonWith('2024-02-30T00:00:00Z', '2024-01-15T00:00:00Z'),
          ),
          throwsFormatException,
        );
        expect(
          () => TaskModel.fromJson(
            jsonWith('2024-01-15T00:00:00Z', '2024-13-01T00:00:00Z'),
          ),
          throwsFormatException,
        );
      });

      test('an unparseable or absent timestamp is rejected', () {
        // Act & Assert
        expect(
          () => TaskModel.fromJson(jsonWith('not-a-date', 'not-a-date')),
          throwsFormatException,
        );
        expect(
          () =>
              TaskModel.fromJson(const {'id': 'task-1', 'title': 'Test Task'}),
          throwsFormatException,
        );
        expect(
          () => TaskModel.fromJson(const {
            'id': 'task-1',
            'title': 'Test Task',
            'created_at': 1705300245,
            'updated_at': 1705300245,
          }),
          throwsFormatException,
        );
      });
    });
  });
}
