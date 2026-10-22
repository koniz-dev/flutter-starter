// The auth slice speaks one wire convention: snake_case.
//
// It used to send `refresh_token` but read `refreshToken`, so a backend that
// answered in the convention the app itself used had its refresh token parsed
// as null and never stored - the first expiry forced a logout. These tests
// capture what the real data source sends and what the models read and
// write, and drive a real login to the token store.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

final RegExp _snakeCase = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');

/// A snake_case auth response, as a backend following the convention sends it.
Map<String, dynamic> _snakeResponse() => {
  'user': {
    'id': 'u-1',
    'email': 'a@b.c',
    'name': 'A',
    'avatar_url': 'https://example.com/a.png',
  },
  'token': 'access-A',
  'refresh_token': 'refresh-R',
};

/// Answers every request with [_snakeResponse] and records each JSON body.
class _RecordingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.data is Map) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    return ResponseBody.fromString(
      jsonEncode(_snakeResponse()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Every key of [json], nested maps included.
Iterable<String> _keys(Map<String, dynamic> json) sync* {
  for (final MapEntry(:key, :value) in json.entries) {
    yield key;
    if (value is Map<String, dynamic>) yield* _keys(value);
  }
}

void main() {
  late InMemoryTokenStore tokens;
  late _RecordingAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    tokens = InMemoryTokenStore();
    adapter = _RecordingAdapter();
    container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(InMemoryStorage()),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
    );
    container.read(apiClientProvider).dio.httpClientAdapter = adapter;
  });

  tearDown(() => container.dispose());

  group('criterion 1: every auth key is snake_case', () {
    test('request bodies of login, register and refresh', () async {
      final remote = container.read(authRemoteDataSourceProvider);
      await remote.login('a@b.c', 'pw123456');
      await remote.register('a@b.c', 'pw123456', 'A');
      await remote.refreshToken('refresh-R');

      expect(adapter.bodies, hasLength(3));
      final keys = adapter.bodies.expand(_keys).toSet();
      expect(keys, contains('refresh_token'));
      expect(keys.where((k) => !_snakeCase.hasMatch(k)), isEmpty);
    });

    test('a snake_case response is read in full', () {
      final model = AuthResponseModel.fromJson(_snakeResponse());

      expect(model.token, 'access-A');
      expect(model.refreshToken, 'refresh-R');
      expect(model.user.avatarUrl, 'https://example.com/a.png');
    });

    test('the response models write snake_case keys back', () {
      final json = AuthResponseModel.fromJson(_snakeResponse()).toJson();

      expect(json, _snakeResponse());
      expect(_keys(json).where((k) => !_snakeCase.hasMatch(k)), isEmpty);
    });
  });

  test('criterion 2: a login response carrying refresh_token persists it to '
      'the token store', () async {
    final result = await container
        .read(authRepositoryProvider)
        .login('a@b.c', 'pw123456');

    expect(result.isSuccess, isTrue);
    expect(tokens.accessToken, 'access-A');
    expect(tokens.refreshToken, 'refresh-R');
  });
}
