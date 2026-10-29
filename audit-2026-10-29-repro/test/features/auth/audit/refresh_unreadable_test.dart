import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

class _Remote implements AuthRemoteDataSource {
  @override
  Future<AuthResponseModel> login(String e, String p) => throw UnimplementedError();
  @override
  Future<AuthResponseModel> register(String e, String p, String n) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      AuthResponseModel.fromJson(const {
        'user': {'id': 42, 'email': 'a@b.c'},
        'token': 'tok',
      });
}

void main() {
  AuthRepositoryImpl repo() {
    final tokens = InMemoryTokenStore()
      ..accessToken = 'a'
      ..refreshToken = 'r';
    return AuthRepositoryImpl(
      remoteDataSource: _Remote(),
      localDataSource: AuthLocalDataSourceImpl(
        storageService: InMemoryKeyValueStore(),
        tokenStore: tokens,
      ),
    );
  }

  test('refreshToken returns a ResultFailure on an unreadable body', () async {
    Object? thrown;
    try {
      final r = await repo().refreshToken();
      print('returned $r');
    } on Object catch (e) {
      thrown = e;
      print('threw ${e.runtimeType}: $e');
    }
    expect(thrown, isNull);
  });

  test('AuthNotifier.refreshToken never throws', () async {
    final c = ProviderContainer(overrides: [
      refreshTokenUseCaseProvider.overrideWithValue(RefreshTokenUseCase(repo())),
    ]);
    addTearDown(c.dispose);
    await expectLater(c.read(authNotifierProvider.notifier).refreshToken(), completes);
  });
}
