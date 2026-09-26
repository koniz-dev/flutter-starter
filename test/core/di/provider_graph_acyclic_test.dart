// The DI graph after koniz-dev/flutter-starter#221 removed the
// `lib/core/di/providers.dart` <-> `lib/features/auth/di/auth_providers.dart`
// import cycle.
//
// The file-level edge is policed by `test/tooling/import_rules_test.dart`.
// What that guard cannot see is whether the *runtime* graph survived the move:
// `authInterceptorProvider` now lives in core and gets its two feature-owned
// dependencies from seams the auth slice overrides. These tests pin the two
// identities that were load-bearing before the change and must still hold.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_stores.dart';

/// Transport that answers every request with 401, as an expired session does.
class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'error': 'token expired'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _seededUser = UserModel(id: 'u1', email: 'seed@example.com');

void main() {
  /// The production graph, with only the two platform-channel dependencies
  /// swapped - the same shape `createAppContainer()` builds.
  ProviderContainer buildContainer({
    required InMemoryStorage storage,
    required InMemoryTokenStore tokens,
    bool wireAuthModule = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        if (wireAuthModule) ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the runtime graph survived breaking the import cycle (#221)', () {
    test(
      'the AuthInterceptor installed in ApiClient is the one '
      'authInterceptorProvider returns',
      () {
        final container = buildContainer(
          storage: InMemoryStorage(),
          tokens: InMemoryTokenStore(),
        );

        final fromProvider = container.read(authInterceptorProvider);
        final installed = container
            .read(apiClientProvider)
            .dio
            .interceptors
            .whereType<AuthInterceptor>()
            .single;

        // Two instances would mean two 401 queues, two replay clients and two
        // session counters - the client would refresh against one and the
        // repository would be guarded by the other.
        expect(identical(fromProvider, installed), isTrue);
      },
    );

    test(
      'AuthRepositoryImpl and the interceptor share one SessionGeneration',
      () async {
        final storage = InMemoryStorage();
        final tokens = InMemoryTokenStore();
        final container = buildContainer(storage: storage, tokens: tokens);

        // Persist a session as a login does, but with no refresh token, so the
        // refresh fails inside real production code without a network call.
        final local = container.read(authLocalDataSourceProvider);
        await local.cacheUser(_seededUser);
        await local.cacheToken('access-token');

        final shared = container.read(sessionGenerationProvider);
        final before = shared.current;

        // The repository half, asserted directly.
        final repository =
            container.read(authRepositoryProvider) as AuthRepositoryImpl;
        expect(identical(repository.sessionGeneration, shared), isTrue);

        // The interceptor half is private, so it is asserted through
        // behaviour: only an interceptor holding *this* instance can move
        // this counter (koniz-dev/flutter-starter#169).
        final apiClient = container.read(apiClientProvider)
          ..dio.httpClientAdapter = _UnauthorizedAdapter();

        await expectLater(
          apiClient.get('/users/me').timeout(const Duration(seconds: 10)),
          throwsA(isA<AppException>()),
        );

        expect(shared.current, greaterThan(before));
        expect(tokens.accessToken, isNull);
      },
    );

    test('core resolves the whole network graph with no feature wired', () {
      // The point of the seam: `lib/core/di/providers.dart` names no feature,
      // so a container without `authModuleOverrides` still builds every
      // provider in it. It simply cannot refresh a session.
      final container = buildContainer(
        storage: InMemoryStorage(),
        tokens: InMemoryTokenStore(),
        wireAuthModule: false,
      );

      expect(container.read(apiClientProvider), isNotNull);
      expect(container.read(authInterceptorProvider), isA<AuthInterceptor>());
      expect(container.read(sessionTerminationSinkProvider), isNull);
    });

    test('the unwired refresher reports which override is missing', () async {
      final container = buildContainer(
        storage: InMemoryStorage(),
        tokens: InMemoryTokenStore(),
        wireAuthModule: false,
      );

      final result = await container.read(tokenRefresherProvider)();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, 'NO_TOKEN_REFRESHER');
      expect(result.failureOrNull?.message, contains('authModuleOverrides'));
    });

    test('authModuleOverrides wires the refresher to the repository', () async {
      final storage = InMemoryStorage();
      final tokens = InMemoryTokenStore();
      final container = buildContainer(storage: storage, tokens: tokens);

      // No refresh token is stored, so the real repository short-circuits with
      // its own failure. Any other code here would mean the seam was still
      // answering instead of the feature.
      final result = await container.read(tokenRefresherProvider)();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, 'No refresh token available');
    });
  });
}
