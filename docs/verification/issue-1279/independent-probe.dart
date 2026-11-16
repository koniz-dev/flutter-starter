import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'file:///Users/nguyenanhkiet/Playground/flutter-starter/test/helpers/in_memory_stores.dart';

AuthResponseModel _response(String id, {bool refresh = true}) =>
    AuthResponseModel.fromJson({
      'user': {'id': id, 'email': '$id@example.test'},
      'token': '$id-access',
      if (refresh) 'refresh_token': '$id-refresh',
    });

bool _failedWrite(String kind) => switch (kind) {
  'false' => false,
  'exception' => throw const CacheException('Fixture write rejected'),
  'error' => throw StateError('Fixture write failed'),
  _ => throw ArgumentError.value(kind),
};

class _Remote implements AuthRemoteDataSource {
  bool includeRefresh = true;
  Exception? error;
  Completer<void>? logoutHold;
  Completer<AuthResponseModel>? loginHold;
  Completer<AuthResponseModel>? refreshHold;
  final refreshRequests = <String>[];
  final requests = <String>[];

  Future<AuthResponseModel> _reply(String email) async {
    final id = email.split('@').first;
    requests.add(id);
    final failure = error;
    if (failure != null) throw failure;
    if (id == 'B' && loginHold != null) return await loginHold!.future;
    return _response(id, refresh: includeRefresh);
  }

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      _reply(email);

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => _reply(email);

  @override
  Future<void> logout({String? refreshToken, String? accessToken}) async {
    await logoutHold?.future;
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    refreshRequests.add(refreshToken);
    final hold = refreshHold;
    if (hold != null) return await hold.future;
    return _response('rotated');
  }
}

class _Service extends Mock implements SecureStorageService {}

class _Storage extends InMemoryStorage {
  String? failedUser;
  String? failureKind;
  String? heldUser;
  bool holdCleanup = false;
  int userRemovals = 0;
  final cleanupStarted = Completer<void>();
  final releaseCleanup = Completer<void>();
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> remove(String key) async {
    if (key == AppConstants.userDataKey && ++userRemovals == 2 && holdCleanup) {
      cleanupStarted.complete();
      await releaseCleanup.future;
    }
    return await super.remove(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (key == AppConstants.userDataKey) {
      final id = (jsonDecode(value) as Map<String, dynamic>)['id'];
      if (id == heldUser) {
        started.complete();
        await release.future;
      }
      // Apply before reporting failure, as an unsuccessful platform future
      // cannot prove that its write had no effect.
      values[key] = value;
      if (id == failedUser) return _failedWrite(failureKind!);
      return true;
    }
    return await super.setString(key, value);
  }
}

class _Fixture {
  _Fixture() {
    tokens = newTokenStore();
    container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
        authRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
  }

  final vault = <String, String>{};
  final writtenTokens = <String>[];
  final storage = _Storage();
  final remote = _Remote();
  String? failedTokenKey;
  String? failedTokenPrefix;
  String? failureKind;
  late final SecureTokenStore tokens;
  late final ProviderContainer container;

  SecureTokenStore newTokenStore() {
    final service = _Service();
    when(() => service.getStringOrThrow(any())).thenAnswer(
      (call) async => vault[call.positionalArguments[0]],
    );
    when(() => service.remove(any())).thenAnswer((call) async {
      vault.remove(call.positionalArguments[0]);
      return true;
    });
    when(() => service.setString(any(), any())).thenAnswer((call) async {
      final key = call.positionalArguments[0] as String;
      final value = call.positionalArguments[1] as String;
      writtenTokens.add(value);
      vault[key] = value;
      if (key == failedTokenKey &&
          (failedTokenPrefix == null || value.startsWith(failedTokenPrefix!))) {
        return _failedWrite(failureKind!);
      }
      return true;
    });
    return SecureTokenStore(service);
  }

  AuthNotifier get notifier => container.read(authNotifierProvider.notifier);

  Future<void> seedSession() async {
    vault[AppConstants.tokenKey] = 'A-access';
    vault[AppConstants.refreshTokenKey] = 'A-refresh';
    storage.values[AppConstants.userDataKey] = jsonEncode(
      _response('A').user.toJson(),
    );
    await notifier.restoreSession();
    expect(container.read(authNotifierProvider).user?.id, 'A');
  }

  AuthRepositoryImpl coldRepository() => AuthRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: AuthLocalDataSourceImpl(
      storageService: storage,
      // A fresh service/store identity cannot hide durable values behind the
      // first store's in-memory revision or pending-write bookkeeping.
      tokenStore: newTokenStore(),
    ),
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void existingMain() {
  late _Fixture fixture;
  setUp(() {
    fixture = _Fixture();
    addTearDown(fixture.container.dispose);
  });

  test(
    'a rejected refresh write cannot be restored by a fresh repository',
    () async {
      await fixture.seedSession();
      fixture
        ..failedTokenKey = AppConstants.refreshTokenKey
        ..failureKind = 'false';
      final result = await fixture.container
          .read(authRepositoryProvider)
          .login('B@example.test', 'password123');
      final restored = await fixture.coldRepository().getCurrentUser();
      expect(result.isSuccess, isFalse);
      expect(restored.dataOrNull, isNull);
    },
  );

  for (final operation in ['login', 'register']) {
    Future<void> signIn() => operation == 'login'
        ? fixture.notifier.login('B@example.test', 'password123')
        : fixture.notifier.register('B@example.test', 'password123', 'B');

    test(
      '$operation without refresh replaces the complete previous pair',
      () async {
        await fixture.seedSession();
        fixture.remote.includeRefresh = false;
        await signIn();
        expect(fixture.container.read(authNotifierProvider).user?.id, 'B');
        expect(await fixture.tokens.getAccessToken(), 'B-access');
        expect(await fixture.tokens.getRefreshToken(), isNull);
        expect(
          (await fixture.coldRepository().getCurrentUser()).dataOrNull?.id,
          'B',
        );
      },
    );

    for (final target in ['access', 'refresh', 'user']) {
      for (final kind in ['false', 'exception', 'error']) {
        test('$operation $target $kind leaves no failed session', () async {
          await fixture.seedSession();
          if (target == 'user') {
            fixture.storage
              ..failedUser = 'B'
              ..failureKind = kind;
          } else {
            fixture
              ..failedTokenKey = target == 'access'
                  ? AppConstants.tokenKey
                  : AppConstants.refreshTokenKey
              ..failureKind = kind;
          }
          await signIn();
          final state = fixture.container.read(authNotifierProvider);
          expect(state.failure, isNotNull);
          expect(state.isLoading, isFalse);
          expect(state.user, isNull);
          // Inspect durable state before restore could perform orphan cleanup.
          expect(fixture.vault, isEmpty);
          expect(
            fixture.storage.values.containsKey(AppConstants.userDataKey),
            isFalse,
          );
          final restored = await fixture.coldRepository().getCurrentUser();
          expect(restored.isSuccess, isTrue);
          expect(restored.dataOrNull, isNull);
        });
      }
    }
  }

  for (final error in <Exception>[
    const ServerException('Rejected', statusCode: 401),
    const NetworkException('Offline'),
  ]) {
    test('remote $error preserves the existing usable session', () async {
      await fixture.seedSession();
      fixture.remote.error = error;
      await fixture.notifier.login('B@example.test', 'password123');
      expect(fixture.container.read(authNotifierProvider).failure, isNotNull);
      expect(fixture.container.read(authNotifierProvider).user?.id, 'A');
      expect(await fixture.tokens.getAccessToken(), 'A-access');
      expect(await fixture.tokens.getRefreshToken(), 'A-refresh');
      expect(
        (await fixture.coldRepository().getCurrentUser()).dataOrNull?.id,
        'A',
      );
    });
  }

  for (final fails in [false, true]) {
    test(
      'a queued sign-in survives an earlier held user write (fails=$fails)',
      () async {
        fixture.storage.heldUser = 'A';
        if (fails) {
          fixture.storage
            ..failedUser = 'A'
            ..failureKind = 'false';
        }
        final first = fixture.notifier.login('A@example.test', 'password123');
        await fixture.storage.started.future;
        final second = fixture.notifier.login('B@example.test', 'password123');
        await _settle();
        final requestsBeforeRelease = List<String>.of(fixture.remote.requests);
        fixture.storage.release.complete();
        await Future.wait([first, second]);

        expect(requestsBeforeRelease, [
          'A',
        ], reason: 'B waits for every earlier local mutation');
        expect(fixture.container.read(authNotifierProvider).user?.id, 'B');
        expect(fixture.container.read(authNotifierProvider).failure, isNull);
        expect(await fixture.tokens.getAccessToken(), 'B-access');
        expect(await fixture.tokens.getRefreshToken(), 'B-refresh');
        expect(
          (await fixture.coldRepository().getCurrentUser()).dataOrNull?.id,
          'B',
        );
      },
    );
  }

  test(
    'a newer sign-in waits until failed persistence rollback settles',
    () async {
      fixture
        ..failedTokenKey = AppConstants.refreshTokenKey
        ..failedTokenPrefix = 'A-'
        ..failureKind = 'false';
      fixture.storage.holdCleanup = true;
      final first = fixture.notifier.login('A@example.test', 'password123');
      await fixture.storage.cleanupStarted.future.timeout(
        const Duration(seconds: 5),
      );
      final second = fixture.notifier.login('B@example.test', 'password123');
      await _settle();
      final requestsBeforeRelease = List<String>.of(fixture.remote.requests);
      fixture.storage.releaseCleanup.complete();
      await Future.wait([first, second]);
      expect(requestsBeforeRelease, ['A']);
      expect(fixture.container.read(authNotifierProvider).user?.id, 'B');
      expect(await fixture.tokens.getAccessToken(), 'B-access');
      expect(await fixture.tokens.getRefreshToken(), 'B-refresh');
      expect(
        (await fixture.coldRepository().getCurrentUser()).dataOrNull?.id,
        'B',
      );
    },
  );

  test(
    'timing out a queued sign-in cannot leave its stale predecessor restorable',
    () async {
      final repository = AuthRepositoryImpl(
        remoteDataSource: fixture.remote,
        localDataSource: AuthLocalDataSourceImpl(
          storageService: fixture.storage,
          tokenStore: fixture.tokens,
        ),
        pendingLogoutLimit: const Duration(milliseconds: 20),
      );
      fixture.storage.heldUser = 'A';
      final first = repository.login('A@example.test', 'password123');
      await fixture.storage.started.future;
      final second = await repository.login('B@example.test', 'password123');
      fixture.storage.release.complete();
      final stale = await first;
      expect(second.failureOrNull?.code, AuthErrorCodes.signOutInProgress);
      expect(stale.failureOrNull?.code, AuthErrorCodes.sessionTerminated);
      expect(fixture.remote.requests, ['A']);
      expect(fixture.vault, isEmpty);
      expect(
        (await fixture.coldRepository().getCurrentUser()).dataOrNull,
        isNull,
      );
    },
  );

  test(
    'restore waits for in-flight sign-in persistence instead of evicting it',
    () async {
      fixture.storage.heldUser = 'A';
      final signIn = fixture.notifier.login('A@example.test', 'password123');
      await fixture.storage.started.future;
      var restored = false;
      final reading = fixture.container
          .read(authRepositoryProvider)
          .getCurrentUser()
          .then((result) {
            restored = true;
            return result;
          });
      await _settle();
      final completedDuringWrite = restored;
      fixture.storage.release.complete();
      await signIn;
      final result = await reading.timeout(const Duration(seconds: 5));
      expect(completedDuringWrite, isFalse);
      expect(result.dataOrNull?.id, 'A');
      expect(fixture.container.read(authNotifierProvider).user?.id, 'A');
      expect(await fixture.tokens.getAccessToken(), 'A-access');
    },
  );

  test(
    'logout clears credentials without waiting on a held user write',
    () async {
      fixture.storage.heldUser = 'A';
      final signIn = fixture.notifier.login('A@example.test', 'password123');
      await fixture.storage.started.future;
      await fixture.notifier.logout().timeout(const Duration(seconds: 5));
      fixture.storage.release.complete();
      await signIn;
      expect(fixture.container.read(authNotifierProvider).user, isNull);
      expect(fixture.vault, isEmpty);
      expect(
        (await fixture.coldRepository().getCurrentUser()).dataOrNull,
        isNull,
      );
    },
  );

  test(
    'restore has a bounded wait without cancelling the pending sign-in',
    () async {
      final source =
          fixture.container.read(authRepositoryProvider) as AuthRepositoryImpl;
      final bounded = AuthRepositoryImpl(
        remoteDataSource: fixture.remote,
        localDataSource: source.localDataSource,
        sessionGeneration: source.sessionGeneration,
        pendingLogoutLimit: const Duration(milliseconds: 20),
      );
      fixture.storage.heldUser = 'A';
      final signIn = fixture.notifier.login('A@example.test', 'password123');
      await fixture.storage.started.future;
      final result = await bounded.getCurrentUser();
      fixture.storage.release.complete();
      await signIn;
      expect(result.failureOrNull?.code, AuthErrorCodes.signOutInProgress);
      expect(fixture.container.read(authNotifierProvider).user?.id, 'A');
      expect(
        (await fixture.coldRepository().getCurrentUser()).dataOrNull?.id,
        'A',
      );
    },
  );

  test('restore does not wait for remote logout acknowledgement', () async {
    await fixture.seedSession();
    final hold = Completer<void>();
    fixture.remote.logoutHold = hold;
    var finished = false;
    final logout = fixture.notifier.logout().then((_) => finished = true);
    await _settle();
    try {
      final result = await fixture.container
          .read(authRepositoryProvider)
          .getCurrentUser()
          .timeout(const Duration(seconds: 2));
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
      expect(finished, isFalse);
    } finally {
      hold.complete();
      await logout;
    }
  });

  test(
    'refresh during a sign-in request cannot restore the old pair',
    () async {
      await fixture.seedSession();
      fixture.remote
        ..loginHold = Completer<AuthResponseModel>()
        ..refreshHold = Completer<AuthResponseModel>();
      final signIn = fixture.notifier.login('B@example.test', 'password123');
      await _settle();
      final refreshing = fixture.container
          .read(authRepositoryProvider)
          .refreshToken();
      await _settle();
      fixture.remote.loginHold!.complete(_response('B', refresh: false));
      await signIn;
      fixture.remote.refreshHold!.complete(_response('old-rotated'));
      final result = await refreshing;
      expect(fixture.remote.refreshRequests, ['A-refresh']);
      expect(result.failureOrNull?.code, AuthErrorCodes.sessionTerminated);
      expect(await fixture.tokens.getAccessToken(), 'B-access');
      expect(await fixture.tokens.getRefreshToken(), isNull);
      expect(
        (await fixture.coldRepository().getCurrentUser()).dataOrNull?.id,
        'B',
      );
    },
  );

  test(
    'refresh refuses an uncommitted pair and works after sign-in settles',
    () async {
      fixture.storage.heldUser = 'A';
      final signIn = fixture.notifier.login('A@example.test', 'password123');
      await fixture.storage.started.future;
      final early = await fixture.container
          .read(authRepositoryProvider)
          .refreshToken();
      final earlyCalls = List<String>.of(fixture.remote.refreshRequests);
      fixture.storage.release.complete();
      await signIn;
      final later = await fixture.container
          .read(authRepositoryProvider)
          .refreshToken();
      expect(early.failureOrNull?.code, AuthErrorCodes.sessionTerminated);
      expect(earlyCalls, isEmpty);
      expect(later.isSuccess, isTrue, reason: '${later.failureOrNull}');
      expect(later.dataOrNull, 'rotated-access');
      expect(fixture.remote.refreshRequests, ['A-refresh']);
      expect(fixture.container.read(authNotifierProvider).user?.id, 'A');
    },
  );

  for (final duringPersistence in [false, true]) {
    test(
      'a listener owns its replacement epoch '
      '(persistence=$duringPersistence)',
      () async {
        await fixture.seedSession();
        final repository = fixture.container.read(
          authRepositoryProvider,
        ) as AuthRepositoryImpl;
        final generation = repository.sessionGeneration;
        var started = false;
        Future<void>? replacement;
        void startReplacement() {
          if (started ||
              generation.hasPendingPersistence != duringPersistence) {
            return;
          }
          started = true;
          replacement = fixture.notifier.login('C@example.test', 'password123');
        }

        generation.addListener(startReplacement);
        addTearDown(() => generation.removeListener(startReplacement));
        final visibleUsers = <String>[];
        final subscription = fixture.container.listen(authNotifierProvider, (
          _,
          state,
        ) {
          final user = state.user;
          if (user != null) visibleUsers.add(user.id);
        });
        addTearDown(subscription.close);
        await fixture.notifier.login('B@example.test', 'password123');
        expect(replacement, isNotNull);
        await replacement;
        expect(fixture.remote.requests, duringPersistence ? ['B', 'C'] : ['C']);
        expect(
          fixture.writtenTokens.where((value) => value.startsWith('B-')),
          isEmpty,
        );
        expect(visibleUsers, isNot(contains('B')));
        expect(fixture.container.read(authNotifierProvider).user?.id, 'C');
        expect(await fixture.tokens.getAccessToken(), 'C-access');
        expect(await fixture.tokens.getRefreshToken(), 'C-refresh');
        expect(
          (await fixture.coldRepository().getCurrentUser()).dataOrNull?.id,
          'C',
        );
      },
    );
  }
}

void main() {
  test('review: completed remote response racing restore barrier', () async {
    final fixture = _Fixture();
    addTearDown(fixture.container.dispose);
    await fixture.seedSession();
    fixture.remote.loginHold = Completer<AuthResponseModel>();
    fixture.storage.heldUser = 'B';
    final repository = fixture.container.read(authRepositoryProvider);
    final login = repository.login('B@example.test', 'password123');
    await _settle();
    fixture.remote.loginHold!.complete(_response('B'));
    final restore = repository.getCurrentUser();
    await _settle();
    fixture.storage.release.complete();
    final results = await Future.wait([login, restore]);
    print('REVIEW results=$results vault=${fixture.vault}');
    expect(results.first.isSuccess, isTrue);
    expect((await fixture.coldRepository().getCurrentUser()).dataOrNull?.id, 'B');
  });
  test('review: transport 401 cannot terminate uncommitted replacement', () async {
    final fixture = _Fixture();
    addTearDown(fixture.container.dispose);
    fixture.storage.heldUser = 'B';
    final repository = fixture.container.read(authRepositoryProvider);
    final login = repository.login('B@example.test', 'password123');
    await fixture.storage.started.future;
    final client = fixture.container.read(apiClientProvider);
    client.dio.httpClientAdapter = _UnauthorizedReview();
    await expectLater(client.get('/users/me').timeout(const Duration(seconds: 5)), throwsA(anything));
    fixture.storage.release.complete();
    final result = await login;
    print('REVIEW 401 sign-in=$result vault=${fixture.vault}');
    expect(result.isSuccess, isTrue);
    expect((await fixture.coldRepository().getCurrentUser()).dataOrNull?.id, 'B');
  });

}

class _UnauthorizedReview implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => ResponseBody.fromString('{}', 401);
  @override
  void close({bool force = false}) {}
}
