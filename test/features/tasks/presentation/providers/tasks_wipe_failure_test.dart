import 'dart:async';
import 'dart:convert';

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
import 'package:flutter_starter/features/tasks/routing/tasks_routes.dart';
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
  Future<void> logout() async {}

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      throw UnimplementedError();
}

/// Storage whose removal, and optionally whose write, of `tasks_data` can be
/// made to fail - a Keystore or disk error at the worst moment.
class _FailingStorage extends InMemoryStorage {
  bool failRemove = false;
  bool failWrite = false;

  @override
  Future<bool> remove(String key) async {
    if (key == _tasksKey && failRemove) throw Exception('remove failed');
    return super.remove(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (key == _tasksKey && failWrite) throw Exception('write failed');
    return super.setString(key, value);
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

// koniz-dev/flutter-starter#458. tasksSessionResetProvider deleted
// `tasks_data` on a session change and invalidated tasksProvider once the
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
