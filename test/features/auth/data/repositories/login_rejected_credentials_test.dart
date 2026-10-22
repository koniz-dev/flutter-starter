// A 401 from the login endpoint must be identifiable as rejected credentials
// without matching on message text.
//
// It used to arrive as a ServerFailure indistinguishable from a server fault.
// This drives the real provider graph - AuthRepositoryImpl, the real remote
// data source, ApiClient and its interceptor chain - with only the transport
// replaced.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({'message': 'Invalid email or password'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<Failure> loginFailureFor(int status) async {
    final container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(InMemoryStorage()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(container.dispose);
    final adapter = _StatusAdapter(status);
    container.read(apiClientProvider).dio.httpClientAdapter = adapter;

    final result = await container
        .read(authRepositoryProvider)
        .login('a@b.c', 'wrong-password');

    expect(adapter.paths, isNotEmpty, reason: 'login never hit the transport');
    expect(result, isA<ResultFailure<dynamic>>());
    return (result as ResultFailure).failure;
  }

  test('criterion 2: a 401 from login is an AuthFailure', () async {
    expect(await loginFailureFor(401), isA<AuthFailure>());
  });

  test('a 500 from login is still a ServerFailure carrying the status, so '
      'the two are told apart by type', () async {
    expect(
      await loginFailureFor(500),
      isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 500),
    );
  });
}
