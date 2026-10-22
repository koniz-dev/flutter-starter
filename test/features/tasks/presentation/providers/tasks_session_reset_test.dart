// Tasks loaded for one user must not reach the next one.
//
// Built on the real provider graph: the real auth repository ends and starts
// sessions, the real tasks data source writes `tasks_data` into one in-memory
// store, and only the network is replaced. The tasks slice learns about the
// session change solely through sessionEpochProvider, because it may not
// import auth.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
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

/// Replies 401 to everything. With no refresh token stored, that drives
/// AuthInterceptor's forced logout.
class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'message': 'Unauthorized'}),
    401,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Storage whose removal of `tasks_data` can be held open, to widen the
/// window between the session ending and the stored tasks being gone.
class _GatedStorage extends InMemoryStorage {
  Completer<void>? tasksRemoval;

  @override
  Future<bool> remove(String key) async {
    if (key == _tasksKey) await tasksRemoval?.future;
    return super.remove(key);
  }
}

/// What the app router does at startup: build the tasks routes.
final Provider<List<RouteBase>> _tasksRoutesProvider = Provider(
  buildTasksRoutes,
);

void main() {
  late _GatedStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = _GatedStorage();
    // Startup: the router builds the tasks routes before anyone signs in.
    container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authRemoteDataSourceProvider.overrideWithValue(_Remote()),
      ],
    )..read(_tasksRoutesProvider);
  });

  tearDown(() => container.dispose());

  Future<void> signIn(String email) async {
    final result = await container
        .read(authRepositoryProvider)
        .login(email, 'pw123456');
    expect(result.isSuccess, isTrue);
    await pumpEventQueue();
  }

  Future<void> logout() async {
    await container.read(authRepositoryProvider).logout();
    await pumpEventQueue();
  }

  /// User A signs in, opens the tasks list and creates a private task.
  Future<void> userACreatesATask() async {
    await signIn('a@example.com');
    final tasks = container.read(tasksProvider.notifier);
    await pumpEventQueue();
    final created = await tasks.createTask(title: "A's private task");
    expect(created.isSuccess, isTrue);
    expect(container.read(tasksProvider).tasks, hasLength(1));
    expect(storage.values, contains(_tasksKey));
  }

  /// The tasks user B sees once the list has (re)loaded.
  Future<List<String>> tasksSeenByNextUser() async {
    container.read(tasksProvider);
    await pumpEventQueue();
    return [for (final task in container.read(tasksProvider).tasks) task.title];
  }

  test('criterion 1: after logout and a sign-in as B, tasksProvider holds no '
      "task of A's", () async {
    await userACreatesATask();

    await logout();
    await signIn('b@example.com');

    expect(await tasksSeenByNextUser(), isEmpty);
  });

  test('criterion 2: logout leaves no tasks_data key in storage', () async {
    await userACreatesATask();

    await logout();

    expect(storage.values, isNot(contains(_tasksKey)));
  });

  test('criterion 3: a forced logout from the interceptor gives the same '
      'result', () async {
    await userACreatesATask();

    final apiClient = container.read(apiClientProvider)
      ..dio.httpClientAdapter = _UnauthorizedAdapter();
    await expectLater(
      apiClient.get('/users/me').timeout(const Duration(seconds: 10)),
      throwsA(isA<AppException>()),
    );
    await pumpEventQueue();
    expect(storage.values, isNot(contains(_tasksKey)));

    await signIn('b@example.com');
    expect(await tasksSeenByNextUser(), isEmpty);
  });

  test("A's stored tasks are wiped even if the tasks screen was never opened "
      'in the session that ended', () async {
    // A's tasks are on disk from an earlier run; this run never builds
    // tasksProvider before the logout.
    storage.values[_tasksKey] = jsonEncode([
      {
        'id': 't-a',
        'title': "A's task from last run",
        'is_completed': false,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      },
    ]);
    await signIn('a@example.com');

    await logout();
    await signIn('b@example.com');

    expect(storage.values, isNot(contains(_tasksKey)));
    expect(await tasksSeenByNextUser(), isEmpty);
  });

  test("a list on screen during the logout does not reload A's tasks while "
      'the stored blob is still being deleted', () async {
    await userACreatesATask();
    // The list screen is open, so a rebuilt notifier reloads at once.
    container.listen(tasksProvider, (_, _) {});
    storage.tasksRemoval = Completer<void>();

    await logout();
    storage.tasksRemoval!.complete();
    await pumpEventQueue();

    expect(storage.values, isNot(contains(_tasksKey)));
    expect(container.read(tasksProvider).tasks, isEmpty);
  });

  test('tasks created in the new session are kept', () async {
    await userACreatesATask();
    await logout();
    await signIn('b@example.com');

    final created = await container
        .read(tasksProvider.notifier)
        .createTask(title: "B's task");
    expect(created.isSuccess, isTrue);
    await pumpEventQueue();

    expect(await tasksSeenByNextUser(), ["B's task"]);
    expect(storage.values, contains(_tasksKey));
  });
}
