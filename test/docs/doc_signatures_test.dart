// Documentation-versus-code gate for constructor signatures.
//
// Two independent checks, deliberately:
//
//  1. `tool/doc_signatures.dart` compares every `<!-- signature: ... -->`
//     block under `docs/` with the constructor it names. That is textual, so
//     it catches a parameter *added* to the source and never documented -
//     drift no compile-time check can see, because an extra optional named
//     parameter breaks nothing that already compiles.
//  2. Constructor tear-offs typed with exactly the documented parameter list.
//     That is a compile-time check, so it catches a documented parameter that
//     does not exist, has the wrong type, or a `required` marker that is not
//     satisfiable.
//
// Check 1 also runs in Docs check (`dart run tool/check_docs.dart`), which
// fires on markdown only. It runs here as well because `ci.yml` skips its
// analyze and test steps on a markdown-only diff, so each gate sees exactly
// one drift direction, and the code side - a constructor gaining a parameter -
// is the direction koniz-dev/flutter-starter#89 actually drifted.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_signatures.dart';

// ---------------------------------------------------------------------------
// Compile-time copies of the signatures documented in
// docs/api/core/network.md. Each tear-off is assigned to a function type
// holding exactly the documented parameter list; the assignment does not
// analyze if a parameter is missing, renamed, retyped, or newly required.
// ---------------------------------------------------------------------------

/// `ApiClient` as documented under "ApiClient -> Constructor".
const ApiClient Function({
  required StorageService storageService,
  required SecureStorageService secureStorageService,
  required AuthInterceptor authInterceptor,
  LoggingService? loggingService,
  IPerformanceService? performanceService,
  SslPinning? sslPinning,
})
documentedApiClient = ApiClient.new;

/// `AuthInterceptor` as documented under "AuthInterceptor -> Constructor".
///
/// The parameter order is the source order, which puts the required one third;
/// `auth_interceptor.dart` suppresses the same lint for the same reason.
const AuthInterceptor Function({
  ITokenStore? tokenStore,
  SecureStorageService? secureStorageService,
  // Source order is the point of this type: reordering would hide a
  // mismatch rather than document one.
  // ignore: always_put_required_named_parameters_first
  required Future<Result<String>> Function() refreshToken,
  Dio Function()? retryDioFactory,
  IKeyValueStore? keyValueStore,
  ISessionTerminationSink? sessionSink,
})
documentedAuthInterceptor = AuthInterceptor.new;

/// `CacheInterceptor` as documented under "CacheInterceptor -> Constructor".
const CacheInterceptor Function({
  required StorageService storageService,
  CacheConfig? cacheConfig,
  ITokenStore? tokenStore,
})
documentedCacheInterceptor = CacheInterceptor.new;

/// `CacheConfig` as documented under "CacheInterceptor -> Constructor".
const CacheConfig Function({
  Duration maxAge,
  Duration maxStale,
  bool enableCache,
})
documentedCacheConfig = CacheConfig.new;

/// `RetryInterceptor` as documented under "RetryInterceptor -> Constructor".
const RetryInterceptor Function({
  required Dio dio,
  LoggingService? loggingService,
  int maxRetries,
  Duration initialExecutionDelay,
})
documentedRetryInterceptor = RetryInterceptor.new;

void main() {
  group('documented constructor signatures', () {
    test('every <!-- signature: --> block matches its source', () {
      expect(
        checkSignatures(Directory.current),
        0,
        reason:
            'A documented constructor no longer matches its source. Run '
            '`dart run tool/check_docs.dart --signatures` for the diff, then '
            'update the fenced block in docs/ to match the code.',
      );
    });

    test('at least one directive exists to check', () {
      // Guards against the check passing because every directive was deleted.
      final doc = File('docs/api/core/network.md').readAsStringSync();
      expect(
        RegExp(r'<!--\s*signature:').allMatches(doc).length,
        greaterThanOrEqualTo(5),
        reason:
            'network.md should keep a signature directive on each of its '
            'documented constructors',
      );
    });

    test('the documented parameter lists compile as written', () {
      // The tear-offs above are the assertion; referencing them here keeps
      // them from being dead code and proves each constructor is reachable
      // through exactly the documented parameter list.
      expect(documentedApiClient, isNotNull);
      expect(documentedAuthInterceptor, isNotNull);
      expect(documentedCacheInterceptor, isNotNull);
      expect(documentedCacheConfig, isNotNull);
      expect(documentedRetryInterceptor, isNotNull);
    });
  });

  group('doc_signatures parser', () {
    test('reads a multi-line named parameter list', () {
      const source = '''
class Sample {
  Sample({
    required String a,
    int? b = 3,
    // a comment
    Future<Result<String>> Function() c,
  }) : _a = a;
}
''';
      expect(namedParameters(source, 'Sample'), [
        'required String a',
        'int? b = 3',
        'Future<Result<String>> Function() c',
      ]);
    });

    test('returns null when the constructor is absent or one-line', () {
      expect(namedParameters('class A {}', 'A'), isNull);
      expect(
        namedParameters('class A { A({required int b}); }', 'A'),
        isNull,
      );
    });
  });
}
