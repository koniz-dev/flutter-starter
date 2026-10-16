// A replayed request must carry its body again (koniz-dev/flutter-starter#284).
//
// AuthInterceptor replays a request after a successful 401 refresh, and
// RetryInterceptor replays one after a transient failure. Both used to pass
// the original body object back to dio. dio finalizes a FormData on its first
// send, so every replayed multipart upload failed with
// `StateError: The FormData has already been finalized`, although the
// refresh had succeeded.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/network/request_body_replay.dart';
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

/// One request as the transport received it.
class _Hit {
  _Hit(this.path, this.authorization, this.body);

  final String path;
  final String? authorization;
  final Uint8List body;

  String get text => utf8.decode(body, allowMalformed: true);
}

/// Transport that reads every request body to the end and answers 401 to the
/// expired token and 200 to any other.
///
/// Reading the body is the point: a replay that cannot produce its body fails
/// before it gets here, and one that sends the wrong body is visible in
/// [hits].
class _BodyRecordingAdapter implements HttpClientAdapter {
  _BodyRecordingAdapter({this.failFirstWith});

  /// When set, the first hit throws this instead of answering.
  final DioExceptionType? failFirstWith;

  final List<_Hit> hits = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final builder = BytesBuilder();
    if (requestStream != null) {
      await requestStream.forEach(builder.add);
    }
    final authorization = options.headers['Authorization'] as String?;
    hits.add(_Hit(options.path, authorization, builder.takeBytes()));

    if (failFirstWith != null && hits.length == 1) {
      throw DioException(requestOptions: options, type: failFirstWith!);
    }
    final expired = authorization == 'Bearer expired-access-token';
    return ResponseBody.fromString(
      jsonEncode({'hit': hits.length}),
      expired ? 401 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// An [AuthInterceptor] whose [seen] completes once it has taken in `count`
/// 401s, so a test can hold the refresh until a second request is queued.
class _CountingAuthInterceptor extends AuthInterceptor {
  _CountingAuthInterceptor({required super.refreshToken, super.tokenStore});

  int errorsSeen = 0;
  final Map<int, Completer<void>> _marks = {};

  Future<void> seen(int count) => errorsSeen >= count
      ? Future<void>.value()
      : (_marks[count] ??= Completer<void>()).future;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) {
    final handled = super.onError(err, handler);
    errorsSeen++;
    final mark = _marks[errorsSeen];
    if (mark != null && !mark.isCompleted) mark.complete();
    return handled;
  }
}

/// A multipart body carrying [bytes] as `upload.bin`, plus a text field.
FormData _upload(List<int> bytes, {String field = 'photo'}) =>
    FormData.fromMap({
      'caption': 'holiday',
      field: MultipartFile.fromBytes(bytes, filename: 'upload.bin'),
    });

/// A recognisable file payload: [marker] repeated, so a body can be matched.
List<int> _payload(String marker) => utf8.encode(marker * 64);

Future<Object?> _thrownBy(Future<Object?> future) async {
  try {
    await future;
    return null;
  } on Object catch (e) {
    return e;
  }
}

void main() {
  late _MockStorageService storageService;
  late _MockSecureStorageService secureStorageService;

  setUp(() {
    storageService = _MockStorageService();
    secureStorageService = _MockSecureStorageService();
  });

  ApiClient buildClient(
    AuthInterceptor authInterceptor,
    _BodyRecordingAdapter adapter,
  ) => ApiClient(
    storageService: storageService,
    secureStorageService: secureStorageService,
    authInterceptor: authInterceptor,
  )..dio.httpClientAdapter = adapter;

  group('a multipart upload replayed after a 401 refresh', () {
    test('reaches the transport again with the file, and the caller gets the '
        '200', () async {
      final adapter = _BodyRecordingAdapter();
      var refreshes = 0;
      final apiClient = buildClient(
        AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async {
            refreshes++;
            return const Success('new-access-token');
          },
        ),
        adapter,
      );

      final response = await apiClient.post(
        '/uploads',
        data: _upload(_payload('A')),
      );

      expect(refreshes, 1);
      expect(response.statusCode, 200);
      expect(adapter.hits, hasLength(2));
      expect(adapter.hits[1].authorization, 'Bearer new-access-token');
      expect(
        adapter.hits[1].text,
        contains('A' * 64),
        reason: 'the replay must carry the file bytes',
      );
      expect(adapter.hits[1].text, contains('holiday'));
      // Same multipart boundary, so the replay is byte-for-byte the upload.
      expect(adapter.hits[1].body, adapter.hits[0].body);
    });

    test(
      'two uploads queued behind one refresh each carry their own file',
      () async {
        final adapter = _BodyRecordingAdapter();
        final release = Completer<void>();
        var refreshes = 0;
        final auth = _CountingAuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async {
            refreshes++;
            await release.future;
            return const Success('new-access-token');
          },
        );
        final apiClient = buildClient(auth, adapter);

        final first = apiClient.post(
          '/uploads/1',
          data: _upload(_payload('X')),
        );
        final second = apiClient.post(
          '/uploads/2',
          data: _upload(_payload('Y')),
        );
        // Both 401s are parked: the first is refreshing, the second is queued
        // for _drainPendingRequests.
        await auth.seen(2);
        release.complete();

        final responses = await Future.wait([first, second]);

        expect(refreshes, 1);
        expect(responses.map((r) => r.statusCode), [200, 200]);
        final replays = adapter.hits
            .where((h) => h.authorization == 'Bearer new-access-token')
            .toList();
        expect(replays.map((h) => h.path).toSet(), {
          '/uploads/1',
          '/uploads/2',
        });
        for (final replay in replays) {
          final marker = replay.path.endsWith('1') ? 'X' : 'Y';
          final other = marker == 'X' ? 'Y' : 'X';
          expect(replay.text, contains(marker * 64), reason: replay.path);
          expect(replay.text, isNot(contains(other * 64)), reason: replay.path);
        }
      },
    );

    test('a Stream body fails the replay with a NetworkException naming the '
        'reason, not a StateError', () async {
      final adapter = _BodyRecordingAdapter();
      final apiClient = buildClient(
        AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success('new-access-token'),
        ),
        adapter,
      );

      final thrown = await _thrownBy(
        apiClient.post(
          '/uploads',
          data: Stream<List<int>>.fromIterable([_payload('S')]),
        ),
      );

      expect(
        thrown,
        isA<NetworkException>().having(
          (e) => e.message,
          'message',
          contains('can be read only once'),
        ),
      );
      expect(thrown.toString(), isNot(contains('StateError')));
      expect(adapter.hits, hasLength(1), reason: 'nothing is replayed');
    });
  });

  group('RetryInterceptor and request bodies', () {
    Dio retryingDio(_BodyRecordingAdapter adapter) {
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(dio: dio, initialExecutionDelay: Duration.zero),
      );
      return dio;
    }

    test('a multipart POST that hits connectionTimeout is retried with the '
        'file', () async {
      final adapter = _BodyRecordingAdapter(
        failFirstWith: DioExceptionType.connectionTimeout,
      );
      final dio = retryingDio(adapter);

      final response = await dio.post<dynamic>(
        '/uploads',
        data: _upload(_payload('R')),
        options: Options(headers: {'Authorization': 'Bearer fresh'}),
      );

      expect(response.statusCode, 200);
      expect(adapter.hits, hasLength(2));
      expect(adapter.hits[1].text, contains('R' * 64));
    });

    test('a Stream body is not retried, and the caller gets the original '
        'failure', () async {
      final adapter = _BodyRecordingAdapter(
        failFirstWith: DioExceptionType.connectionTimeout,
      );
      final dio = retryingDio(adapter);

      final thrown = await _thrownBy(
        dio.post<dynamic>(
          '/uploads',
          data: Stream<List<int>>.fromIterable([_payload('S')]),
        ),
      );

      expect(
        thrown,
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionTimeout,
        ),
      );
      expect(adapter.hits, hasLength(1));
    });
  });

  group('RequestBodyReplay', () {
    test('clones a FormData and passes reusable bodies through', () {
      final form = _upload(_payload('C'));
      final replayed = RequestBodyReplay.bodyFor(form);

      expect(replayed, isA<FormData>());
      expect(identical(replayed, form), isFalse);
      for (final body in <Object?>[
        null,
        'text',
        {'k': 'v'},
        [1, 2],
        Uint8List(3),
      ]) {
        expect(RequestBodyReplay.canReplay(body), isTrue, reason: '$body');
        expect(identical(RequestBodyReplay.bodyFor(body), body), isTrue);
      }
      expect(RequestBodyReplay.canReplay(const Stream<int>.empty()), isFalse);
    });
  });
}
