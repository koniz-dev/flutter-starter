// Regression cover for koniz-dev/flutter-starter#59.
//
// Two defects: the 401 replay client built its own bare Dio, so the freshly
// minted access token travelled over an unpinned transport; and requesting
// pinning without fingerprints disabled it in silence.

import 'package:dio/io.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/adapters/shared_transport_adapter.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _InMemoryTokenStore implements ITokenStore {
  String? accessToken = 'expired-access-token';

  @override
  Future<void> clearAccessToken() async => accessToken = null;

  @override
  Future<void> clearAllTokens() async => accessToken = null;

  @override
  Future<void> clearRefreshToken() async {}

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => 'refresh-token';

  @override
  Future<bool> setAccessToken(String token) async {
    accessToken = token;
    return true;
  }

  @override
  Future<bool> setRefreshToken(String token) async => true;
}

// A plausible SHA-256 fingerprint; never actually matched in these tests.
const _fingerprint =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  group('SslPinning', () {
    test('is effective only when enabled with fingerprints', () {
      const off = SslPinning(enabled: false, fingerprints: []);
      const requestedButEmpty = SslPinning(enabled: true, fingerprints: []);
      const pinned = SslPinning(enabled: true, fingerprints: [_fingerprint]);

      expect(off.isEffective, isFalse);
      expect(off.isMisconfigured, isFalse);
      expect(requestedButEmpty.isEffective, isFalse);
      expect(requestedButEmpty.isMisconfigured, isTrue);
      expect(pinned.isEffective, isTrue);
      expect(pinned.isMisconfigured, isFalse);
    });

    test('builds a pinned adapter when fingerprints are present', () {
      const pinned = SslPinning(enabled: true, fingerprints: [_fingerprint]);

      expect(pinned.createAdapter(), isA<IOHttpClientAdapter>());
    });

    test('returns no adapter when pinning is disabled', () {
      const off = SslPinning(enabled: false, fingerprints: [_fingerprint]);

      expect(off.createAdapter(), isNull);
    });

    test('fails loudly when enabled with no fingerprints', () {
      const misconfigured = SslPinning(enabled: true, fingerprints: []);

      // Criterion 6: an assertion trips in debug builds instead of quietly
      // falling back to the system trust store. Release builds keep the
      // logged error (debugPrint) that precedes the assert.
      expect(
        misconfigured.createAdapter,
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            SslPinning.misconfiguredMessage,
          ),
        ),
      );
    });
  });

  group('401 replay transport', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
    });

    ApiClient buildClient(AuthInterceptor authInterceptor, SslPinning pinning) {
      return ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: authInterceptor,
        sslPinning: pinning,
      );
    }

    test('replays through the main client pinned adapter', () {
      final authInterceptor = AuthInterceptor(
        tokenStore: _InMemoryTokenStore(),
        refreshToken: () async => const Success<String>('unused'),
      );
      final apiClient = buildClient(
        authInterceptor,
        const SslPinning(enabled: true, fingerprints: [_fingerprint]),
      );

      // The main client is pinned...
      expect(apiClient.dio.httpClientAdapter, isA<IOHttpClientAdapter>());

      // Criterion 3: ...and the replay client resolves to that same adapter
      // instance rather than a bare, system-trust-store transport.
      final retryAdapter = authInterceptor.retryDio().httpClientAdapter;
      expect(retryAdapter, isA<SharedTransportAdapter>());
      expect(
        identical(
          (retryAdapter as SharedTransportAdapter).target,
          apiClient.dio.httpClientAdapter,
        ),
        isTrue,
      );
    });

    test('follows the main client transport when it is swapped', () {
      final authInterceptor = AuthInterceptor(
        tokenStore: _InMemoryTokenStore(),
        refreshToken: () async => const Success<String>('unused'),
      );
      final apiClient = buildClient(
        authInterceptor,
        const SslPinning(enabled: true, fingerprints: [_fingerprint]),
      );
      final retryAdapter =
          authInterceptor.retryDio().httpClientAdapter
              as SharedTransportAdapter;

      final replacement = IOHttpClientAdapter();
      apiClient.dio.httpClientAdapter = replacement;

      expect(identical(retryAdapter.target, replacement), isTrue);
    });

    test('inherits the main client base url and timeouts', () {
      final authInterceptor = AuthInterceptor(
        tokenStore: _InMemoryTokenStore(),
        refreshToken: () async => const Success<String>('unused'),
      );
      final apiClient = buildClient(
        authInterceptor,
        const SslPinning(enabled: false, fingerprints: []),
      );

      final retryDio = authInterceptor.retryDio();
      expect(retryDio.options.baseUrl, apiClient.dio.options.baseUrl);
      expect(
        retryDio.options.connectTimeout,
        apiClient.dio.options.connectTimeout,
      );
      // The replay must not re-enter the interceptor chain it came from.
      expect(retryDio.interceptors.whereType<AuthInterceptor>(), isEmpty);
    });
  });
}
