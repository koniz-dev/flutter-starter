import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _RejectingStore extends InMemoryKeyValueStore {
  @override
  Future<bool> setString(String key, String value) async => false;

  @override
  Future<bool> remove(String key) async => false;
}

void main() {
  test('a rejected user write is reported to the sign-in caller', () async {
    final storage = _RejectingStore();
    final dataSource = AuthLocalDataSourceImpl(
      storageService: storage,
      tokenStore: InMemoryTokenStore(),
    );

    await expectLater(
      dataSource.cacheUser(
        const UserModel(id: 'a', email: 'a@example.com', name: 'A'),
      ),
      throwsA(isA<CacheException>()),
    );
    expect(storage.values, isEmpty);
  });

  test(
    'a rejected user deletion still clears both tokens and reports failure',
    () async {
      final storage = _RejectingStore()
        ..values[AppConstants.userDataKey] = '{"id":"a"}';
      final tokens = InMemoryTokenStore()
        ..accessToken = 'access'
        ..refreshToken = 'refresh';
      final dataSource = AuthLocalDataSourceImpl(
        storageService: storage,
        tokenStore: tokens,
      );

      await expectLater(
        dataSource.clearCache(),
        throwsA(isA<CacheException>()),
      );
      expect(storage.values, contains(AppConstants.userDataKey));
      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
    },
  );
}
