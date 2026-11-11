// API_SEND_TIMEOUT and API_TIMEOUT were documented, parsed and never applied:
// ApiClient set only connect and receive
// timeouts, and nothing read AppConfig.apiTimeout. These tests load a `.env`
// with distinctive values and assert both reach the wire.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/adapters/dio_network_client.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

const _assetChannel = 'flutter/assets';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// A transport that never answers until its request is cancelled.
class _HangingAdapter implements HttpClientAdapter {
  int fetches = 0;
  bool cancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    fetches++;
    final hang = Completer<ResponseBody>();
    unawaited(
      cancelFuture?.then((_) {
        cancelled = true;
        if (!hang.isCompleted) {
          hang.completeError(
            DioException.requestCancelled(
              requestOptions: options,
              reason: 'cancelled',
            ),
          );
        }
      }),
    );
    return hang.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var environmentLoads = 0;
  Future<void> loadEnvironment(String values) async {
    final fileName = 'timeouts_env_${environmentLoads++}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != fileName) return null;
          final bytes = Uint8List.fromList(utf8.encode(values));
          return ByteData.view(bytes.buffer);
        });
    await EnvConfig.load(fileName: fileName);
    expect(EnvConfig.isInitialized, isTrue);
  }

  setUp(() => loadEnvironment('API_TIMEOUT=1\nAPI_SEND_TIMEOUT=7\n'));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  });

  ApiClient buildClient(HttpClientAdapter adapter) {
    return ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      ),
    )..dio.httpClientAdapter = adapter;
  }

  group('criterion 1: API_SEND_TIMEOUT reaches both Dio instances', () {
    test('ApiClient sets sendTimeout from AppConfig.apiSendTimeout', () {
      final client = buildClient(_HangingAdapter());

      expect(client.dio.options.sendTimeout, const Duration(seconds: 7));
    });

    test('the 401 replay client borrows it from the host options', () {
      final authInterceptor = AuthInterceptor(
        tokenStore: InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      );
      ApiClient(
        storageService: InMemoryStorage(),
        secureStorageService: _MockSecureStorageService(),
        authInterceptor: authInterceptor,
      );

      expect(
        authInterceptor.retryDio().options.sendTimeout,
        const Duration(seconds: 7),
      );
    });

    test('a replay client with no host falls back to AppConfig', () {
      final authInterceptor = AuthInterceptor(
        tokenStore: InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      );

      expect(
        authInterceptor.retryDio().options.sendTimeout,
        const Duration(seconds: 7),
      );
    });
  });

  group('criterion 2: API_TIMEOUT is an end-to-end deadline per request', () {
    test('ApiClient gives up on a hanging request after API_TIMEOUT, as a '
        'timeout, and cancels it', () async {
      final adapter = _HangingAdapter();
      final client = buildClient(adapter);
      final watch = Stopwatch()..start();

      await expectLater(
        client.get('/slow'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.code,
            'code',
            'RECEIVE_TIMEOUT',
          ),
        ),
      );

      watch.stop();
      expect(watch.elapsed, greaterThanOrEqualTo(const Duration(seconds: 1)));
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      await pumpEventQueue();
      expect(adapter.cancelled, isTrue);
    });

    for (final seconds in [0, -1]) {
      test('API_TIMEOUT=$seconds disables the total deadline', () async {
        await loadEnvironment('API_TIMEOUT=$seconds\n');
        final adapter = _AnsweringAdapter(
          delay: const Duration(milliseconds: 50),
        );
        final client = buildClient(adapter);

        final response = await client.get('/delayed');

        expect(response.statusCode, 200);
        expect(response.data, {'ok': true});
        expect(adapter.fetches, 1);
      });
    }

    test(
      'shipped total and receive budgets both default to 30 seconds',
      () async {
        await loadEnvironment('API_SEND_TIMEOUT=7\n');
        final client = buildClient(_HangingAdapter());

        expect(AppConfig.apiTimeout, 30);
        expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
      },
    );

    test('DioNetworkClient without a deadline leaves the request alone', () {
      final adapter = _HangingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = DioNetworkClient(dio);

      final pending = client.send(
        const NetworkRequest(path: '/slow', method: NetworkMethod.get),
      );

      return expectLater(
        pending.timeout(const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('a response inside the deadline is returned untouched', () async {
      final dio = Dio()
        ..httpClientAdapter = _AnsweringAdapter(
          delay: const Duration(milliseconds: 50),
        );
      final client = DioNetworkClient(
        dio,
        deadline: const Duration(seconds: 2),
      );

      final response = await client.send(
        const NetworkRequest(path: '/fast', method: NetworkMethod.get),
      );

      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
    });
  });
}

class _AnsweringAdapter implements HttpClientAdapter {
  _AnsweringAdapter({required this.delay});

  final Duration delay;
  int fetches = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetches++;
    await Future<void>.delayed(delay);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
