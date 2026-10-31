// A session change must be observable outside the auth slice.
//
// Features may not import lib/features/auth/ (import_rules_test), so per-user
// state elsewhere - the tasks slice, say - needs a signal from
// lib/core/session/. SessionGeneration already advances on every transition
// that replaces or removes the credential set; these tests pin that each one is
// now *observable*, through sessionEpochProvider, on the real provider graph.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/session/session_providers.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_stores.dart';

const _user = UserModel(id: 'u-1', email: 'a@b.c', name: 'A');

/// A backend that accepts every call, so only the session bookkeeping is
/// under test.
class _AcceptingRemote implements AuthRemoteDataSource {
  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      const AuthResponseModel(user: _user, token: 'access');

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async => const AuthResponseModel(user: _user, token: 'access');

  @override
  Future<void> logout({String? refreshToken}) async {}

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      const AuthResponseModel(user: _user, token: 'access');
}

/// Replies 401 to everything, which drives AuthInterceptor's forced logout
/// when there is no refresh token to try.
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

void main() {
  late ProviderContainer container;
  late InMemoryTokenStore tokens;
  late List<int> epochs;

  setUp(() {
    tokens = InMemoryTokenStore();
    container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(InMemoryStorage()),
        tokenStoreProvider.overrideWithValue(tokens),
        authRemoteDataSourceProvider.overrideWithValue(_AcceptingRemote()),
      ],
    );
    epochs = [];
    container.listen<int>(
      sessionEpochProvider,
      (_, next) => epochs.add(next),
      fireImmediately: true,
    );
  });

  tearDown(() => container.dispose());

  group('criterion 1: SessionGeneration notifies on invalidate', () {
    test(
      'every invalidate() notifies, and current/isCurrent are unchanged',
      () {
        final generation = SessionGeneration();
        var notified = 0;
        generation.addListener(() => notified++);

        final first = generation.current;
        generation
          ..invalidate()
          ..invalidate();

        expect(notified, 2);
        expect(generation.current, first + 2);
        expect(generation.isCurrent(first), isFalse);
        expect(generation.isCurrent(generation.current), isTrue);
      },
    );
  });

  test('a removed listener is no longer called', () {
    final generation = SessionGeneration();
    var notified = 0;
    void listener() => notified++;
    generation
      ..addListener(listener)
      ..invalidate()
      ..removeListener(listener)
      ..invalidate();
    expect(notified, 1);
  });

  group('a throwing listener cannot interrupt a teardown', () {
    test('invalidate() still advances, runs the rest, and does not throw', () {
      final generation = SessionGeneration();
      final reported = <Object>[];
      var laterListenerRan = false;
      final first = generation.current;

      runZonedGuarded(
        () => generation
          ..addListener(() => throw StateError('listener bug'))
          ..addListener(() => laterListenerRan = true)
          ..invalidate(),
        (error, _) => reported.add(error),
      );

      expect(generation.isCurrent(first), isFalse);
      expect(laterListenerRan, isTrue);
      expect(reported, [isA<StateError>()]);
    });

    test('forced logout still clears the tokens', () async {
      final reported = <Object>[];
      await runZonedGuarded(
        () async {
          container
              .read(sessionGenerationProvider)
              .addListener(() => throw StateError('listener bug'));
          final local = container.read(authLocalDataSourceProvider);
          await local.cacheUser(_user);
          await local.cacheToken('access');
          final apiClient = container.read(apiClientProvider)
            ..dio.httpClientAdapter = _UnauthorizedAdapter();
          await expectLater(
            apiClient.get('/users/me').timeout(const Duration(seconds: 10)),
            throwsA(isA<AppException>()),
          );
        },
        (error, _) => reported.add(error),
      );

      expect(tokens.accessToken, isNull);
      expect(reported, contains(isA<StateError>()));
    });
  });

  group('criteria 2-3: each transition reaches sessionEpochProvider', () {
    test('logout', () async {
      await container.read(authRepositoryProvider).logout();
      expect(epochs, hasLength(2), reason: '$epochs');
      expect(epochs.last, greaterThan(epochs.first));
    });

    test('login', () async {
      await container.read(authRepositoryProvider).login('a@b.c', 'pw123456');
      expect(epochs, hasLength(2), reason: '$epochs');
      expect(epochs.last, greaterThan(epochs.first));
    });

    test('register', () async {
      await container
          .read(authRepositoryProvider)
          .register('a@b.c', 'pw123456', 'A');
      expect(epochs, hasLength(2), reason: '$epochs');
      expect(epochs.last, greaterThan(epochs.first));
    });

    test('forced logout raised inside AuthInterceptor', () async {
      // A session with no refresh token: the 401's refresh fails in real code
      // and the interceptor forces the logout.
      final local = container.read(authLocalDataSourceProvider);
      await local.cacheUser(_user);
      await local.cacheToken('access');
      final apiClient = container.read(apiClientProvider)
        ..dio.httpClientAdapter = _UnauthorizedAdapter();

      await expectLater(
        apiClient.get('/users/me').timeout(const Duration(seconds: 10)),
        throwsA(isA<AppException>()),
      );

      expect(epochs.length, greaterThanOrEqualTo(2), reason: '$epochs');
      expect(epochs.last, greaterThan(epochs.first));
      expect(tokens.accessToken, isNull);
    });
  });
}
