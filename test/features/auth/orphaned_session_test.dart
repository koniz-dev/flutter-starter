import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _SecureService extends Mock implements SecureStorageService {}

class _Unauthorized implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{}', 401);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final entry in <String, Object?>{
    'missing': null,
    'invalid JSON': '{broken',
    'invalid user fields': jsonEncode({'id': 7, 'email': 'a@example.com'}),
    'wrong preference type': 7,
    'valid': jsonEncode({'id': 'user-1', 'email': 'a@example.com'}),
  }.entries) {
    test('restore handles ${entry.key} user cache', () async {
      final storage = InMemoryStorage();
      if (entry.value != null) {
        storage.values[AppConstants.userDataKey] = entry.value;
      }
      final vault = <String, String>{
        AppConstants.tokenKey: 'orphan-access',
        AppConstants.refreshTokenKey: 'orphan-refresh',
      };
      final service = _SecureService();
      when(() => service.getStringOrThrow(any())).thenAnswer(
        (call) async => vault[call.positionalArguments[0]],
      );
      when(() => service.remove(any())).thenAnswer((call) async {
        vault.remove(call.positionalArguments[0]);
        return true;
      });
      final tokens = SecureTokenStore(service);
      final container = ProviderContainer(
        overrides: [
          ...authModuleOverrides,
          storageServiceProvider.overrideWithValue(storage),
          tokenStoreProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.notifier).restoreSession();
      if (entry.key == 'valid') {
        expect(container.read(authNotifierProvider).user?.id, 'user-1');
        expect(await tokens.getAccessToken(), 'orphan-access');
        expect(await tokens.getRefreshToken(), 'orphan-refresh');
        return;
      }
      expect(container.read(authNotifierProvider).user, isNull);
      expect(await tokens.getAccessToken(), isNull);
      expect(await tokens.getRefreshToken(), isNull);
      expect(storage.values.containsKey(AppConstants.userDataKey), isFalse);

      final adapter = _Unauthorized();
      final client = container.read(apiClientProvider);
      client.dio.httpClientAdapter = adapter;
      await expectLater(
        client.get('/users/me').timeout(const Duration(seconds: 5)),
        throwsA(anything),
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(
        adapter.requests.where((request) => request.path.contains('refresh')),
        isEmpty,
      );
    });
  }
}
