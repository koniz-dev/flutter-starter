/// Proves the [TasksLocalDataSourceImpl] storage seam is real, not nominal.
///
/// The store handed in here implements **only** `IKeyValueStore`. It is not a
/// `StorageService`, there is no `SharedPreferences.setMockInitialValues`, and
/// no platform channel is touched. If the data source ever reaches for the
/// concrete service again this file stops compiling.
library;

import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

void main() {
  group('TasksLocalDataSourceImpl on a bare IKeyValueStore', () {
    late InMemoryKeyValueStore store;
    late TasksLocalDataSourceImpl dataSource;

    setUp(() {
      store = InMemoryKeyValueStore();
      dataSource = TasksLocalDataSourceImpl(storageService: store);
    });

    test('writes a task and reads it back', () async {
      final task = TaskModel(
        id: 'task-1',
        title: 'Write the seam test',
        description: 'No SharedPreferences involved',
        createdAt: DateTime.utc(2024, 1, 15, 7, 30, 45),
        updatedAt: DateTime.utc(2024, 1, 15, 8),
      );

      await dataSource.saveTask(task);

      final all = await dataSource.getAllTasks();
      expect(all, hasLength(1));
      expect(all.single.id, 'task-1');
      expect(all.single.title, 'Write the seam test');
      expect(all.single.description, 'No SharedPreferences involved');
      expect(all.single.isCompleted, isFalse);

      final byId = await dataSource.getTaskById('task-1');
      expect(byId, isNotNull);
      expect(byId!.createdAt.toUtc(), DateTime.utc(2024, 1, 15, 7, 30, 45));
      expect(byId.updatedAt.toUtc(), DateTime.utc(2024, 1, 15, 8));
    });

    test('persists under the unchanged tasks_data key', () async {
      await dataSource.saveTask(
        TaskModel(
          id: 'task-1',
          title: 'A',
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2024),
        ),
      );

      expect(store.values.keys, ['tasks_data']);
      expect(store.values['tasks_data'], isA<String>());
      expect(store.values['tasks_data'], contains('"id":"task-1"'));
    });

    test('deleteAllTasks removes the key', () async {
      await dataSource.saveTask(
        TaskModel(
          id: 'task-1',
          title: 'A',
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2024),
        ),
      );
      await dataSource.deleteAllTasks();

      expect(store.values, isEmpty);
      expect(await dataSource.getAllTasks(), isEmpty);
    });
  });
}
