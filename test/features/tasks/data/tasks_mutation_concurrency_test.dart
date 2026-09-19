import 'dart:async';

import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/json_helper.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_starter/features/tasks/data/repositories/tasks_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_fixtures.dart';

class MockStorageService extends Mock implements StorageService {}

/// A pending `getString`.
class _Read {
  _Read(this.completer);

  final Completer<String?> completer;
}

/// A pending `setString`.
class _Write {
  _Write(this.value, this.completer);

  final String value;
  final Completer<bool> completer;
}

/// A `StorageService` whose reads and writes only resolve when the test says
/// so, driven in explicit rounds.
///
/// Every call made *before* a round is settled is settled together, so two
/// operations that both read before either writes really do see the same
/// snapshot - that is the read-read-write-write interleaving that loses an
/// update. Nothing here depends on wall-clock timing or `Future.delayed`.
class _ControlledStorage {
  _ControlledStorage(this.mock, {String? initial}) : _stored = initial {
    when(() => mock.getString(any())).thenAnswer((_) {
      final completer = Completer<String?>();
      _pending.add(_Read(completer));
      return completer.future;
    });
    when(() => mock.setString(any(), any())).thenAnswer((invocation) {
      final value = invocation.positionalArguments[1] as String;
      final completer = Completer<bool>();
      _pending.add(_Write(value, completer));
      return completer.future;
    });
  }

  final MockStorageService mock;
  final List<Object> _pending = [];
  String? _stored;

  /// Calls awaiting a response right now.
  int get pendingCount => _pending.length;

  /// The JSON currently committed to storage.
  String? get stored => _stored;

  /// Number of rounds it took to drain every queued call.
  int rounds = 0;

  /// Settles everything queued so far, then lets the awaiting code run and
  /// queue its next call. Repeats until nothing is pending.
  Future<void> drain() async {
    // The first storage call is dispatched from a microtask, so let the
    // queue turn once before deciding there is nothing to settle.
    await pumpEventQueue();
    while (_pending.isNotEmpty) {
      rounds++;
      if (rounds > 50) fail('storage calls never stopped arriving');
      final batch = List<Object>.of(_pending);
      _pending.clear();
      for (final call in batch) {
        if (call is _Read) {
          call.completer.complete(_stored);
        } else if (call is _Write) {
          _stored = call.value;
          call.completer.complete(true);
        }
      }
      await pumpEventQueue();
    }
  }
}

String _encode(List<TaskModel> tasks) =>
    JsonHelper.encode(tasks.map((task) => task.toJson()).toList())!;

List<TaskModel> _decode(String? json) => (JsonHelper.decodeList(
  json ?? '[]',
)!).map((entry) => TaskModel.fromJson(entry as Map<String, dynamic>)).toList();

void main() {
  late MockStorageService mockStorageService;
  late _ControlledStorage storage;
  late TasksLocalDataSourceImpl dataSource;
  late TasksRepositoryImpl repository;

  final taskA = createTaskModel(id: 'a', title: 'Task A');
  final taskB = createTaskModel(id: 'b', title: 'Task B');

  setUp(() {
    mockStorageService = MockStorageService();
    storage = _ControlledStorage(
      mockStorageService,
      initial: _encode([taskA, taskB]),
    );
    dataSource = TasksLocalDataSourceImpl(storageService: mockStorageService);
    repository = TasksRepositoryImpl(localDataSource: dataSource);
  });

  group('concurrent tasks mutations', () {
    test(
      'a delete and a toggle issued together both survive '
      '(no lost update)',
      () async {
        // Act - both mutations are issued before either has read anything.
        final delete = repository.deleteTask('a');
        final toggle = repository.toggleTaskCompletion('b');

        await storage.drain();
        await Future.wait([delete, toggle]);

        // Assert - A stays deleted and B stays toggled. Before the fix the
        // two read-modify-write cycles overlapped, the toggle wrote a
        // snapshot taken before the delete, and A came back from the dead.
        final stored = _decode(storage.stored);
        expect(
          stored.map((task) => task.id),
          ['b'],
          reason: 'deleted task A must not be resurrected by the toggle',
        );
        expect(
          stored.single.isCompleted,
          isTrue,
          reason: 'the toggle of B must not be lost to the delete',
        );
      },
    );

    test('the two mutations never read concurrently', () async {
      // Act
      final delete = repository.deleteTask('a');
      final toggle = repository.toggleTaskCompletion('b');

      // Assert - only one storage call can be outstanding at a time, which
      // is what makes the interleaving above impossible. Two pending calls
      // here would mean two unsynchronised read-modify-write cycles.
      await pumpEventQueue();
      expect(storage.pendingCount, 1);

      await storage.drain();
      await Future.wait([delete, toggle]);
    });

    test('two toggles of the same task apply both flips', () async {
      // Act - a double flip must land on the original value, not on `true`
      // twice. This is the data-layer half of the double-tap defect.
      final first = repository.toggleTaskCompletion('b');
      final second = repository.toggleTaskCompletion('b');

      await storage.drain();
      final results = await Future.wait([first, second]);

      // Assert
      expect(results.every((result) => result.isSuccess), isTrue);
      final stored = _decode(storage.stored);
      expect(stored.firstWhere((task) => task.id == 'b').isCompleted, isFalse);
    });

    test('a queued mutation still runs after an earlier one fails', () async {
      // Arrange - fail the very first write, leave later ones working.
      var writes = 0;
      when(() => mockStorageService.setString(any(), any())).thenAnswer((
        invocation,
      ) async {
        writes++;
        if (writes == 1) throw Exception('disk full');
        return true;
      });
      when(
        () => mockStorageService.getString(any()),
      ).thenAnswer((_) async => _encode([taskA, taskB]));

      // Act
      final failing = dataSource.deleteTask('a');
      final following = dataSource.deleteTask('b');

      // Assert - the failure does not poison the serialisation queue.
      await expectLater(failing, throwsA(isA<Exception>()));
      await expectLater(following, completes);
      expect(writes, 2);
    });

    test('mutateTasks sees every earlier mutation', () async {
      // Arrange - a plain immediate storage fake, so ordering is the only
      // thing under test.
      var stored = _encode([taskA]);
      when(
        () => mockStorageService.getString(any()),
      ).thenAnswer((_) async => stored);
      when(() => mockStorageService.setString(any(), any())).thenAnswer((
        invocation,
      ) async {
        stored = invocation.positionalArguments[1] as String;
        return true;
      });

      // Act - ten upserts issued without awaiting any of them.
      await Future.wait([
        for (var i = 0; i < 10; i++)
          dataSource.saveTask(createTaskModel(id: 'task-$i')),
      ]);

      // Assert - every one is present: none overwrote another's snapshot.
      final ids = _decode(stored).map((task) => task.id).toSet();
      expect(ids, hasLength(11));
      expect(ids.contains('a'), isTrue);
    });
  });
}
