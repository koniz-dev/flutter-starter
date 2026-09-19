// Regression cover for koniz-dev/flutter-starter#59.
//
// Two defects: the 401 replay client built its own bare Dio, so the freshly
// minted access token travelled over an unpinned transport; and requesting
// pinning without fingerprints disabled it in silence.

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

// A plausible SHA-256 fingerprint; never matches [_certificateBytes].
const _fingerprint =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// Stand-in DER bytes for a server certificate. The pinning check only ever
/// hashes `cert.der`, so real ASN.1 is not needed to exercise it.
final Uint8List _certificateBytes = Uint8List.fromList(
  List<int>.generate(64, (i) => i),
);

String _hashOf(Uint8List der) => sha256.convert(der).toString().toLowerCase();

/// Minimal [X509Certificate]: the pinning check reads only [der].
class _FakeCertificate implements X509Certificate {
  _FakeCertificate(this.der);

  @override
  final Uint8List der;

  @override
  DateTime get endValidity => DateTime.utc(2099);

  @override
  String get issuer => 'CN=Test CA';

  @override
  String get pem => '-----BEGIN CERTIFICATE-----';

  @override
  Uint8List get sha1 => Uint8List(20);

  @override
  DateTime get startValidity => DateTime.utc(2020);

  @override
  String get subject => 'CN=api.example.com';
}

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

    // Criterion 4 of #53. These assert the *wiring* of the pinning branch:
    // which adapter an ApiClient ends up with, and what the installed
    // fingerprint check answers. Real TLS behaviour - an actual handshake
    // against a server presenting a mismatched certificate - is tier 3 and is
    // not verified here.
    test('the pinned adapter installs a certificate check', () {
      const pinned = SslPinning(enabled: true, fingerprints: [_fingerprint]);

      final adapter = pinned.createAdapter()! as IOHttpClientAdapter;

      // A non-null createHttpClient is what distinguishes the pinned
      // transport from Dio's default one: it is the hook that installs the
      // empty trust store plus badCertificateCallback.
      expect(adapter.createHttpClient, isNotNull);
      expect(adapter.createHttpClient!(), isA<HttpClient>());
    });

    test('accepts a certificate whose fingerprint is pinned', () {
      final cert = _FakeCertificate(_certificateBytes);
      final pinning = SslPinning(
        enabled: true,
        fingerprints: [_hashOf(_certificateBytes)],
      );

      expect(pinning.acceptsCertificate(cert, host: 'api.example.com'), isTrue);
    });

    test('rejects a certificate whose fingerprint is not pinned', () {
      final cert = _FakeCertificate(_certificateBytes);
      const pinning = SslPinning(
        enabled: true,
        fingerprints: [_fingerprint],
      );

      expect(
        pinning.acceptsCertificate(cert, host: 'api.example.com'),
        isFalse,
        reason: 'an unpinned certificate must not be trusted',
      );
    });

    test('rejects every certificate when the pin list is empty', () {
      final cert = _FakeCertificate(_certificateBytes);
      const pinning = SslPinning(enabled: true, fingerprints: []);

      expect(pinning.acceptsCertificate(cert), isFalse);
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

    test('installs the pinned adapter, and only when pinning is on', () {
      // Criterion 4 of #53: the unpinned case is not "some IOHttpClientAdapter"
      // - Dio's default transport is one of those too. What separates them is
      // the createHttpClient hook, which only the pinned policy sets.
      final pinnedClient = buildClient(
        AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success<String>('unused'),
        ),
        const SslPinning(enabled: true, fingerprints: [_fingerprint]),
      );
      final unpinnedClient = buildClient(
        AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success<String>('unused'),
        ),
        const SslPinning(enabled: false, fingerprints: [_fingerprint]),
      );

      final pinnedAdapter =
          pinnedClient.dio.httpClientAdapter as IOHttpClientAdapter;
      final unpinnedAdapter =
          unpinnedClient.dio.httpClientAdapter as IOHttpClientAdapter;

      expect(pinnedAdapter.createHttpClient, isNotNull);
      expect(
        unpinnedAdapter.createHttpClient,
        isNull,
        reason: 'pinning off must leave Dio on its default transport',
      );
    });

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
