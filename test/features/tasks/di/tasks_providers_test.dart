import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tasks_providers (smoke)', () {
    test('should build tasks providers with default DI', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(tasksLocalDataSourceProvider),
        isA<TasksLocalDataSource>(),
      );
      expect(container.read(tasksRepositoryProvider), isA<TasksRepository>());
      expect(container.read(getAllTasksUseCaseProvider), isNotNull);
      expect(container.read(getTaskByIdUseCaseProvider), isNotNull);
      expect(container.read(createTaskUseCaseProvider), isNotNull);
      expect(container.read(updateTaskUseCaseProvider), isNotNull);
      expect(container.read(deleteTaskUseCaseProvider), isNotNull);
      expect(container.read(toggleTaskCompletionUseCaseProvider), isNotNull);
    });
  });
}
