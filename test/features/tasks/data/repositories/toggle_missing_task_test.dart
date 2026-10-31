// Toggling a task that is not stored returned CacheFailure('Task not found'),
// which is localised as a storage error, though storage worked.

import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/repositories/tasks_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

void main() {
  test('toggling a task that is not stored is a NotFoundFailure', () async {
    final repository = TasksRepositoryImpl(
      localDataSource: TasksLocalDataSourceImpl(
        storageService: InMemoryKeyValueStore(),
      ),
    );

    final result = await repository.toggleTaskCompletion('missing');

    expect(result, isA<ResultFailure<Object?>>());
    expect((result as ResultFailure).failure, isA<NotFoundFailure>());
  });
}
