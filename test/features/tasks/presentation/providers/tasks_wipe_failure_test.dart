import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/features/tasks/routing/tasks_routes.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/in_memory_stores.dart';

const _tasksKey = 'tasks_data';

/// Signs in whoever's email is given; every other call succeeds.
class _Remote implements AuthRemoteDataSource {
  AuthResponseModel _session(String email) => AuthResponseModel(
    user: UserModel(id: email, email: email, name: email),
    token: 'access-$email',
  );

  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      _session(email);

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async => _session(email);

  @override
  Future<void> logout({String? refreshToken, String? accessToken}) async {}

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      throw UnimplementedError();
}

/// Storage whose removal, and optionally whose write, of `tasks_data` can be
/// made to fail - a Keystore or disk error at the worst moment.
class _FailingStorage extends InMemoryStorage {
  bool failRemove = false;
  bool failWrite = false;
  bool returnFalse = false;
  Completer<void>? heldRemoval;
  int taskRemovals = 0;

  @override
  Future<bool> remove(String key) async {
    if (key == _tasksKey) {
      taskRemovals++;
      final gate = heldRemoval;
      if (gate != null) await gate.future;
    }
    if (key == _tasksKey && failRemove) {
      if (returnFalse) return false;
      throw Exception('remove failed');
    }
    return await super.remove(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (key == _tasksKey && failWrite) {
      if (returnFalse) return false;
      throw Exception('write failed');
    }
    return await super.setString(key, value);
  }
}

class _RecordingLoggingService extends LoggingService {
  _RecordingLoggingService() : super(enableLogging: false);

  final List<String> errors = [];

  @override
  void error(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => errors.add(message);
}

/// What the app router does at startup: build the tasks routes.
final Provider<List<RouteBase>> _tasksRoutesProvider = Provider(
  buildTasksRoutes,
);

// tasksSessionResetProvider used to delete `tasks_data` on a session change
// and invalidate tasksProvider once the
// delete *finished* - whether or not it succeeded. A failed delete therefore
// let the rebuilt notifier reload the previous user's tasks for the next one,
// and the error reached only the zone's uncaught-error handler.
void main() {
  late _FailingStorage storage;
  late _RecordingLoggingService logger;
  late ProviderContainer container;
  late List<Object> uncaught;

  setUp(() {
    storage = _FailingStorage();
    logger = _RecordingLoggingService();
    uncaught = [];
    container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authRemoteDataSourceProvider.overrideWithValue(_Remote()),
        loggingServiceProvider.overrideWithValue(logger),
      ],
    )..read(_tasksRoutesProvider);
  });

  tearDown(() => container.dispose());

  /// Runs [body] recording any error that escapes to the zone.
  Future<void> guarded(Future<void> Function() body) {
    final done = Completer<void>();
    runZonedGuarded(
      () => unawaited(body().then(done.complete, onError: done.completeError)),
      (error, _) => uncaught.add(error),
    );
    return done.future;
  }

  Future<void> signIn(String email) async {
    final result = await container
        .read(authRepositoryProvider)
        .login(email, 'pw123456');
    expect(result.isSuccess, isTrue);
    await pumpEventQueue();
  }

  /// A signs in and creates a task, then logs out while [failing] storage
  /// errors are switched on; B signs in.
  Future<void> handOverToB({required bool failWrite}) async {
    await signIn('a@example.com');
    container.read(tasksProvider);
    await pumpEventQueue();
    final created = await container
        .read(tasksProvider.notifier)
        .createTask(title: "A's private task");
    expect(created.isSuccess, isTrue);

    storage
      ..failRemove = true
      ..failWrite = failWrite;
    await container.read(authRepositoryProvider).logout();
    await pumpEventQueue();
    await signIn('b@example.com');
  }

  List<String> titlesOnScreen() => [
    for (final task in container.read(tasksProvider).tasks) task.title,
  ];

  Future<List<String>> titlesAfterReload() async {
    await container.read(tasksProvider.notifier).refresh();
    await pumpEventQueue();
    return titlesOnScreen();
  }

  test('criterion 1: a failed delete falls back to an empty list, so B sees '
      "none of A's tasks, now or on a reload", () async {
    await guarded(() => handOverToB(failWrite: false));

    container.read(tasksProvider);
    await pumpEventQueue();
    expect(titlesOnScreen(), isEmpty);
    expect(await titlesAfterReload(), isEmpty);
    expect(jsonDecode(storage.values[_tasksKey]! as String), isEmpty);
  });

  test('criterion 1: when the fallback write fails too, the list is held '
      'empty until a wipe succeeds', () async {
    await guarded(() => handOverToB(failWrite: true));

    container.read(tasksProvider);
    await pumpEventQueue();
    expect(titlesOnScreen(), isEmpty);
    expect(await titlesAfterReload(), isEmpty, reason: 'still held empty');
    expect(
      storage.values,
      contains(_tasksKey),
      reason: "A's blob really is still stored - the hold is what protects B",
    );

    // Storage recovers: the next load retries the wipe, and it sticks.
    storage
      ..failRemove = false
      ..failWrite = false;
    expect(await titlesAfterReload(), isEmpty);
    expect(storage.values, isNot(contains(_tasksKey)));

    final created = await container
        .read(tasksProvider.notifier)
        .createTask(title: "B's task");
    expect(created.isSuccess, isTrue);
    expect(await titlesAfterReload(), ["B's task"]);
  });

  test('concurrent session wipes share a single deletion', () async {
    final gate = storage.heldRemoval = Completer<void>();
    final wipe = container.read(tasksSessionWipeProvider);
    final first = wipe.run();
    final second = wipe.run();
    try {
      await pumpEventQueue();
      expect(storage.taskRemovals, 1);
    } finally {
      gate.complete();
      await Future.wait([first, second]);
    }
    expect(storage.taskRemovals, 1);
    expect(wipe.pending, isFalse);
  });

  test('detail reads cannot bypass a failed session wipe', () async {
    await guarded(() => handOverToB(failWrite: true));
    final rows = jsonDecode(storage.values[_tasksKey]! as String) as List;
    final id = (rows.first as Map<String, dynamic>)['id'] as String;
    final result = await container.read(tasksProvider.notifier).taskById(id);
    result.when(
      success: (task) => expect(task, isNull),
      failureCallback: (failure) => fail(failure.message),
    );
  });

  test('a rejected task write reports failure instead of success', () async {
    await signIn('a@example.com');
    container.read(tasksProvider);
    await pumpEventQueue();
    storage
      ..returnFalse = true
      ..failWrite = true;

    final created = await container
        .read(tasksProvider.notifier)
        .createTask(title: 'Not persisted');

    expect(created.isFailure, isTrue);
    expect(storage.values, isNot(contains(_tasksKey)));
    expect(container.read(tasksProvider).isLoading, isFalse);
  });

  for (final failWrite in [false, true]) {
    test('false storage results protect the next session '
        '(fallback fails: $failWrite)', () async {
      storage.returnFalse = true;
      await guarded(() => handOverToB(failWrite: failWrite));

      container.read(tasksProvider);
      await pumpEventQueue();
      expect(titlesOnScreen(), isEmpty);
      expect(await titlesAfterReload(), isEmpty);
      expect(uncaught, isEmpty);
      if (failWrite) {
        expect(storage.values[_tasksKey], contains("A's private task"));
        expect(container.read(tasksSessionWipeProvider).pending, isTrue);
        final blocked = await container
            .read(tasksProvider.notifier)
            .createTask(title: 'Blocked while cleanup fails');
        expect(blocked.isFailure, isTrue);
        expect(container.read(tasksProvider).isLoading, isFalse);
        expect(
          storage.values[_tasksKey],
          isNot(contains('Blocked while cleanup fails')),
        );
      } else {
        expect(jsonDecode(storage.values[_tasksKey]! as String), isEmpty);
      }

      storage
        ..failRemove = false
        ..failWrite = false;
      final created = await container
          .read(tasksProvider.notifier)
          .createTask(title: "B's new task");
      expect(created.isSuccess, isTrue);
      expect(await titlesAfterReload(), ["B's new task"]);
    });
  }

  for (final failWrite in [false, true]) {
    testWidgets('screen never renders the previous user after false storage '
        '(fallback fails: $failWrite)', (tester) async {
      storage.returnFalse = true;
      await tester.runAsync(() async {
        await guarded(() => handOverToB(failWrite: failWrite));
        await titlesAfterReload();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TasksListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("A's private task"), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      await tester.runAsync(titlesAfterReload);
      await tester.pumpAndSettle();
      expect(find.text("A's private task"), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(uncaught, isEmpty);
      if (failWrite) {
        expect(container.read(tasksSessionWipeProvider).pending, isTrue);
      }
      storage
        ..failRemove = false
        ..failWrite = false;
      await tester.runAsync(() async {
        final result = await container
            .read(tasksProvider.notifier)
            .createTask(title: "B's visible task");
        expect(result.isSuccess, isTrue);
        await titlesAfterReload();
      });
      await tester.pumpAndSettle();
      expect(find.text("B's visible task"), findsOneWidget);
      expect(find.text("A's private task"), findsNothing);
      expect(find.byType(ListTile), findsOneWidget);
      expect(uncaught, isEmpty);
    });
  }

  test(
    'criterion 2: each failure is logged, and none escapes to the zone',
    () async {
      await guarded(() => handOverToB(failWrite: true));
      await pumpEventQueue();

      // The logout and B's sign-in are both session changes, so each runs
      // the wipe: the delete fails and is logged, then the fallback fails and
      // is logged.
      expect(logger.errors.take(2), [
        contains('could not delete'),
        contains('could not overwrite'),
      ]);
      expect(
        logger.errors,
        everyElement(
          anyOf(contains('could not delete'), contains('could not overwrite')),
        ),
      );
      expect(uncaught, isEmpty);
    },
  );
}
