import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_stores.dart';

class _SecureService extends Mock implements SecureStorageService {}

class _Tokens extends InMemoryTokenStore {
  final writes = <String>[];
  int clears = 0;
  Object? snapshotError;
  void Function()? afterSnapshot;
  AccessTokenWriteResult? forcedConditional;
  void Function()? afterConditional;

  @override
  Future<void> clearAllTokens() {
    clears++;
    return super.clearAllTokens();
  }

  @override
  Future<AccessTokenSnapshot?> getAccessTokenSnapshot() async {
    final snapshot = await super.getAccessTokenSnapshot();
    final hook = afterSnapshot;
    afterSnapshot = null;
    hook?.call();
    final error = snapshotError;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
    return snapshot;
  }

  int reads = 0;
  int? holdRead;
  final readEntered = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<String?> getAccessToken() async {
    final snapshot = await super.getAccessToken();
    if (++reads == holdRead) {
      readEntered.complete();
      await releaseRead.future;
    }
    return snapshot;
  }

  @override
  Future<AccessTokenWriteResult> setAccessTokenIfCurrent(
    AccessTokenSnapshot expected,
    String token,
  ) async {
    final forced = forcedConditional;
    if (forced != null) {
      // A failed reservation still changes revision. A conflict is modeled
      // by another actor replacing the credentials before this comparison.
      if (forced == AccessTokenWriteResult.conflict) {
        accessToken = 'external';
        refreshToken = 'external-refresh';
      } else {
        await trackCredentialMutation<void>(() {});
      }
      final hook = afterConditional;
      if (hook != null) scheduleMicrotask(hook);
      return forced;
    }
    final outcome = await super.setAccessTokenIfCurrent(expected, token);
    if (outcome == AccessTokenWriteResult.applied) writes.add(token);
    return outcome;
  }

  @override
  Future<bool> setAccessToken(String token) {
    writes.add(token);
    return super.setAccessToken(token);
  }
}

class _RotatingRemote implements AuthRemoteDataSource {
  int rotation = 1;
  String Function(int)? accessForRotation;
  String get currentAccess => accessForRotation?.call(rotation) ?? 'A$rotation';

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    expect(refreshToken, 'R$rotation');
    rotation++;
    return AuthResponseModel(
      user: const UserModel(id: 'u', email: 'u@example.test'),
      token: currentAccess,
      refreshToken: 'R$rotation',
    );
  }

  @override
  Future<void> logout({String? refreshToken, String? accessToken}) async {}

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final int Function(RequestOptions) status;
  final bearers = <Object?>[];
  final entered = Completer<void>();
  Completer<void>? release;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bearers.add(options.headers['Authorization']);
    if (!entered.isCompleted) entered.complete();
    if (release != null) await release!.future;
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      status(options),
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ObservedInterceptor extends AuthInterceptor {
  _ObservedInterceptor({
    required super.tokenStore,
    required super.refreshToken,
    required super.sessionGeneration,
    required super.retryDioFactory,
    super.keyValueStore,
  });

  final secondError = Completer<void>();
  int errors = 0;

  @override
  Future<void> onError(DioException error, ErrorInterceptorHandler handler) {
    final handling = super.onError(error, handler);
    if (++errors == 2) secondError.complete();
    return handling;
  }
}

Future<Object> _settle(Future<Response<dynamic>> request) async {
  try {
    return await request;
  } on Object catch (error) {
    return error;
  }
}

Future<T> _within<T>(Future<T> future) =>
    future.timeout(const Duration(seconds: 5));

void main() {
  late _Tokens tokens;
  late InMemoryKeyValueStore preferences;
  late SessionGeneration generation;
  late _RotatingRemote remote;
  late AuthRepositoryImpl repository;
  late _Adapter original;
  late _Adapter replay;

  setUp(() {
    tokens = _Tokens()
      ..accessToken = 'A1'
      ..refreshToken = 'R1';
    preferences = InMemoryKeyValueStore();
    generation = SessionGeneration();
    remote = _RotatingRemote();
    repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(
        storageService: preferences,
        tokenStore: tokens,
      ),
      sessionGeneration: generation,
    );
    original = _Adapter((_) => 401);
    replay = _Adapter(
      (options) =>
          options.headers['Authorization'] == 'Bearer ${remote.currentAccess}'
          ? 200
          : 401,
    );
  });

  ({Dio dio, _ObservedInterceptor interceptor}) client(
    Future<Result<String>> Function() refresh, {
    ITokenStore? store,
  }) {
    final interceptor = _ObservedInterceptor(
      tokenStore: store ?? tokens,
      keyValueStore: preferences,
      sessionGeneration: generation,
      refreshToken: refresh,
      retryDioFactory: () => Dio()..httpClientAdapter = replay,
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = original
      ..interceptors.add(interceptor);
    addTearDown(() {
      interceptor.dispose();
      dio.close(force: true);
    });
    return (dio: dio, interceptor: interceptor);
  }

  test(
    'delayed repository callback preserves a later rotation for all replays',
    () async {
      final callbackReady = Completer<void>();
      final releaseCallback = Completer<void>();
      final pair = client(() async {
        final result = await repository.refreshToken();
        callbackReady.complete();
        await releaseCallback.future;
        return result;
      });
      final first = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(callbackReady.future);
      final second = _settle(pair.dio.get<dynamic>('/tasks'));
      await _within(pair.interceptor.secondError.future);

      expect((await repository.refreshToken()).isSuccess, isTrue);
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      releaseCallback.complete();
      final outcomes = await _within(Future.wait([first, second]));

      expect(tokens.writes, ['A2', 'A3'], reason: 'no late duplicate A2 write');
      expect(replay.bearers, ['Bearer A3', 'Bearer A3']);
      expect(
        outcomes.every((value) => value is Response && value.statusCode == 200),
        isTrue,
      );
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
    },
  );

  test(
    'a callback that only returns a token is still persisted and replayed',
    () async {
      replay = _Adapter((_) => 200);
      final pair = client(() async => const Success('A2'));
      final response = await _within(pair.dio.get<dynamic>('/profile'));
      expect(response.statusCode, 200);
      expect(tokens.writes, ['A2']);
      expect(tokens.accessToken, 'A2');
      expect(replay.bearers, ['Bearer A2']);
    },
  );

  test(
    'a rotation before the callback starts does not suppress its new result',
    () async {
      original.release = Completer<void>();
      replay = _Adapter((_) => 200);
      final pair = client(() async => const Success('A3'));
      final pending = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(original.entered.future);
      await tokens.setAccessToken('A2');
      original.release!.complete();
      expect(await _within(pending), isA<Response<dynamic>>());
      expect(tokens.accessToken, 'A3');
      expect(tokens.writes, ['A2', 'A3']);
      expect(replay.bearers, ['Bearer A3']);
    },
  );

  test('a repository-persisted refresh is not written a second time', () async {
    final pair = client(repository.refreshToken);
    final response = await _within(pair.dio.get<dynamic>('/profile'));
    expect(response.statusCode, 200);
    expect(tokens.writes, ['A2']);
    expect(tokens.refreshToken, 'R2');
    expect(replay.bearers, ['Bearer A2']);
  });
  test('ABA rotations preserve the newer access/refresh pairing', () async {
    remote.accessForRotation = (rotation) =>
        rotation == 3 ? 'A1' : 'A$rotation';
    final ready = Completer<void>();
    final release = Completer<void>();
    final pair = client(() async {
      final result = await repository.refreshToken();
      ready.complete();
      await release.future;
      return result;
    });
    final pending = _settle(pair.dio.get<dynamic>('/profile'));
    await _within(ready.future);
    expect((await repository.refreshToken()).isSuccess, isTrue);
    expect(tokens.accessToken, 'A1');
    release.complete();
    expect(await _within(pending), isA<DioException>());
    expect(tokens.writes, ['A2', 'A1']);
    expect(tokens.refreshToken, 'R3');
    expect(replay.bearers, isEmpty);
    expect(tokens.clears, 0);
  });

  test(
    'a stale held snapshot read never replays or deletes a newer rotation',
    () async {
      tokens.holdRead = 3;
      final pair = client(repository.refreshToken);
      final pending = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(tokens.readEntered.future);
      expect((await repository.refreshToken()).isSuccess, isTrue);
      tokens.releaseRead.complete();
      final outcome = await _within(pending);
      expect(outcome, isA<DioException>());
      expect((outcome as DioException).type, DioExceptionType.cancel);
      expect(tokens.writes, ['A2', 'A3']);
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test('a new session during snapshot selection is untouched', () async {
    tokens.holdRead = 3;
    final pair = client(() async => const Success('A2'));
    final pending = _settle(pair.dio.get<dynamic>('/profile'));
    await _within(tokens.readEntered.future);
    generation.invalidate();
    await tokens.setAccessToken('different-user');
    await tokens.setRefreshToken('different-refresh');
    tokens.releaseRead.complete();
    expect(await _within(pending), isA<DioException>());
    expect(tokens.accessToken, 'different-user');
    expect(tokens.refreshToken, 'different-refresh');
    expect(tokens.clears, 0);
    expect(replay.bearers, isEmpty);
  });

  test(
    'a revision changed after certification is rechecked before dispatch',
    () async {
      final pair = client(() async {
        tokens.afterSnapshot = () {
          tokens
            ..accessToken = 'external'
            ..refreshToken = 'external-refresh';
        };
        return const Success('A2');
      });
      expect(
        await _within(_settle(pair.dio.get<dynamic>('/profile'))),
        isA<DioException>(),
      );
      expect(tokens.accessToken, 'external');
      expect(tokens.refreshToken, 'external-refresh');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test('conditional conflict rejects without replay or teardown', () async {
    tokens.forcedConditional = AccessTokenWriteResult.conflict;
    final pair = client(() async => const Success('A2'));
    expect(
      await _within(_settle(pair.dio.get<dynamic>('/profile'))),
      isA<DioException>(),
    );
    expect(tokens.accessToken, 'external');
    expect(tokens.refreshToken, 'external-refresh');
    expect(tokens.clears, 0);
    expect(replay.bearers, isEmpty);
  });

  test(
    'a failed adoption cannot delete credentials installed after its result',
    () async {
      tokens.forcedConditional = AccessTokenWriteResult.failed;
      tokens.afterConditional = () {
        tokens
          ..accessToken = 'external'
          ..refreshToken = 'external-refresh';
      };
      final pair = client(() async => const Success('A2'));
      expect(
        await _within(_settle(pair.dio.get<dynamic>('/profile'))),
        isA<DioException>(),
      );
      expect(tokens.accessToken, 'external');
      expect(tokens.refreshToken, 'external-refresh');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test(
    'a snapshot read error after success preserves the newer stored session',
    () async {
      final pair = client(() async {
        final result = await repository.refreshToken();
        expect((await repository.refreshToken()).isSuccess, isTrue);
        tokens.snapshotError = StateError('platform read failed');
        return result;
      });
      expect(
        await _within(_settle(pair.dio.get<dynamic>('/profile'))),
        isA<DioException>(),
      );
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test(
    'a later rotation during replay survives its old 401 and feeds the queue',
    () async {
      replay.release = Completer<void>();
      final pair = client(repository.refreshToken);
      final first = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(replay.entered.future);
      final second = _settle(pair.dio.get<dynamic>('/tasks'));
      await _within(pair.interceptor.secondError.future);
      expect((await repository.refreshToken()).isSuccess, isTrue);
      replay.release!.complete();
      final outcomes = await _within(Future.wait([first, second]));
      expect(outcomes.first, isA<DioException>());
      expect(outcomes.last, isA<Response<dynamic>>());
      expect(replay.bearers, ['Bearer A2', 'Bearer A3']);
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      expect(tokens.clears, 0);
    },
  );
  test(
    'the secure adapter refuses a timed out stale snapshot after rotation',
    () async {
      final service = _SecureService();
      final values = <String, String>{
        AppConstants.tokenKey: 'A1',
        AppConstants.refreshTokenKey: 'R1',
      };
      final readEntered = Completer<void>();
      final releaseRead = Completer<void>();
      var accessReads = 0;
      var removals = 0;
      when(() => service.getStringOrThrow(any())).thenAnswer((call) async {
        final key = call.positionalArguments[0] as String;
        final captured = values[key];
        if (key == AppConstants.tokenKey && ++accessReads == 3) {
          readEntered.complete();
          await releaseRead.future;
        }
        return captured;
      });
      when(() => service.setString(any(), any())).thenAnswer((call) async {
        values[call.positionalArguments[0] as String] =
            call.positionalArguments[1] as String;
        return true;
      });
      when(() => service.remove(any())).thenAnswer((call) async {
        removals++;
        values.remove(call.positionalArguments[0] as String);
        return true;
      });
      final store = SecureTokenStore(
        service,
        operationTimeout: const Duration(milliseconds: 5),
      );
      final realRepository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: AuthLocalDataSourceImpl(
          storageService: preferences,
          tokenStore: store,
        ),
        sessionGeneration: generation,
      );
      final pair = client(realRepository.refreshToken, store: store);
      final request = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(readEntered.future);
      // Queue timeout lets the newer repository write complete while the old
      // platform read is still held. Certification must not bless its A2.
      expect((await _within(realRepository.refreshToken())).isSuccess, isTrue);
      releaseRead.complete();
      final outcome = await _within(request);
      expect(outcome, isA<DioException>());
      expect(replay.bearers, isEmpty);
      expect(values[AppConstants.tokenKey], 'A3');
      expect(values[AppConstants.refreshTokenKey], 'R3');
      expect(removals, 0);
      expect((await store.getAccessTokenSnapshot())?.token, 'A3');
    },
  );
  test(
    'partial callback persistence is rejected without clearing its credentials',
    () async {
      final pair = client(() async {
        await tokens.setRefreshToken('R2');
        return const Success('A2');
      });
      final outcome = await _within(_settle(pair.dio.get<dynamic>('/profile')));
      expect(outcome, isA<DioException>());
      expect((outcome as DioException).type, DioExceptionType.cancel);
      expect(tokens.accessToken, 'A1');
      expect(tokens.refreshToken, 'R2');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
      expect(tokens.writes, isEmpty);
    },
  );
  for (final throws in [false, true]) {
    test(
      'an ${throws ? 'error' : 'uncertain read'} before refresh '
      'preserves credentials',
      () async {
        var callbackCalled = false;
        if (throws) {
          tokens.snapshotError = StateError('read failed');
        } else {
          tokens.afterSnapshot = () {
            tokens
              ..accessToken = 'external'
              ..refreshToken = 'external-refresh';
          };
        }
        final pair = client(() async {
          callbackCalled = true;
          return const Success('A2');
        });
        expect(
          await _within(_settle(pair.dio.get<dynamic>('/profile'))),
          isA<DioException>(),
        );
        expect(callbackCalled, isFalse);
        expect(tokens.accessToken, throws ? 'A1' : 'external');
        expect(tokens.refreshToken, throws ? 'R1' : 'external-refresh');
        expect(tokens.clears, 0);
        expect(replay.bearers, isEmpty);
      },
    );
  }
}
