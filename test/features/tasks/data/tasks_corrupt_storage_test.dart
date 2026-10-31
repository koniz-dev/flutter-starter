// A stored task row with a wrong-typed field made TaskModel.fromJson throw a
// TypeError - an Error, not an Exception - which passed every `on Exception`
// handler, escaped the repository's Result and left the task list loading
// forever. An undecodable list was the opposite: read as "no tasks", so the
// next save overwrote it without a word. Both are now a CacheFailure.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_starter/features/tasks/data/repositories/tasks_repository_impl.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

const _stamp =
    '"created_at":"2024-01-01T00:00:00Z",'
    '"updated_at":"2024-01-01T00:00:00Z"';

/// Stored lists, each holding one row a reader cannot accept.
const _badRows = {
  'an int id': '[{"id":1,"title":"t",$_stamp}]',
  'a null title': '[{"id":"a","title":null,$_stamp}]',
  'is_completed: 1': '[{"id":"a","title":"t","is_completed":1,$_stamp}]',
  'a non-object element': '[1]',
};

const _undecodable = '[{"id":"a","title":"t"';

TasksRepositoryImpl _repository(InMemoryKeyValueStore storage) =>
    TasksRepositoryImpl(
      localDataSource: TasksLocalDataSourceImpl(storageService: storage),
    );

void main() {
  group('TaskModel.fromJson', () {
    final good = <String, dynamic>{
      'id': 'a',
      'title': 't',
      'created_at': '2024-01-01T00:00:00Z',
      'updated_at': '2024-01-01T00:00:00Z',
    };
    for (final (field, value) in <(String, Object?)>[
      ('id', 1),
      ('title', null),
      ('description', 7),
      ('is_completed', 1),
    ]) {
      test('a wrong-typed $field is a FormatException', () {
        expect(
          () => TaskModel.fromJson({...good, field: value}),
          throwsFormatException,
        );
      });
    }
  });

  for (final MapEntry(key: label, value: blob) in {
    ..._badRows,
    'an undecodable list': _undecodable,
  }.entries) {
    group('a stored list with $label', () {
      late InMemoryKeyValueStore storage;

      setUp(
        () => storage = InMemoryKeyValueStore()..values['tasks_data'] = blob,
      );

      test('fails reads with a CacheFailure instead of throwing', () async {
        final repository = _repository(storage);

        final all = await repository.getAllTasks();
        final one = await repository.getTaskById('a');

        expect(all, isA<ResultFailure<Object?>>());
        expect((all as ResultFailure).failure, isA<CacheFailure>());
        expect((one as ResultFailure).failure, isA<CacheFailure>());
      });

      test('leaves the task list settled with a failure, and every mutation '
          'fails without overwriting the stored list', () async {
        final uncaught = <Object>[];
        await runZonedGuarded(() async {
          final container = ProviderContainer(
            overrides: [
              tasksLocalDataSourceProvider.overrideWithValue(
                TasksLocalDataSourceImpl(storageService: storage),
              ),
            ],
          );
          addTearDown(container.dispose);
          final sub = container.listen(tasksProvider, (_, _) {});
          addTearDown(sub.close);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          var state = container.read(tasksProvider);
          expect(state.isLoading, isFalse, reason: 'load settled');
          expect(state.failure, isNotNull);

          final notifier = container.read(tasksProvider.notifier);
          final created = await notifier.createTask(title: 'new');
          expect(created, isA<ResultFailure<Object?>>());
          await notifier.toggleTaskCompletion('a');
          await notifier.deleteTask('a');
          state = container.read(tasksProvider);
          expect(state.isLoading, isFalse);
          expect(state.failure, isNotNull);
        }, (error, _) => uncaught.add(error));

        expect(uncaught, isEmpty);
        expect(storage.values['tasks_data'], blob, reason: 'not overwritten');
      });
    });
  }
}
