// A login or register body the app cannot parse stays inside Result.
//
// The generated fromJson casts with `as String`, so an int user id or a
// missing token throws a TypeError. AuthRepositoryImpl caught only
// AppException and Exception, so the Error escaped, and AuthNotifier - which
// had already set isLoading - never reset it: the login screen spun forever.
// The fake remote below parses each body through the real generated code.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class _MockLoginUseCase extends Mock implements LoginUseCase {}

/// Answers login and register with [body], parsed by the generated code.
class _BodyRemoteDataSource implements AuthRemoteDataSource {
  _BodyRemoteDataSource(this.body);

  final Map<String, dynamic> body;

  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      AuthResponseModel.fromJson(body);

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async => AuthResponseModel.fromJson(body);

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<void> logout({String? refreshToken}) async {}
}

/// The issue's body: a numeric user id, as many backends send.
const Map<String, dynamic> _intUserId = {
  'user': {'id': 42, 'email': 'a@b.c'},
  'token': 'tok',
};

/// A body with a valid user but no token.
const Map<String, dynamic> _missingToken = {
  'user': {'id': 'u-1', 'email': 'a@b.c'},
};

void main() {
  late _MockAuthLocalDataSource local;

  setUp(() {
    local = _MockAuthLocalDataSource();
  });

  AuthRepositoryImpl repositoryFor(Map<String, dynamic> body) =>
      AuthRepositoryImpl(
        remoteDataSource: _BodyRemoteDataSource(body),
        localDataSource: local,
      );

  for (final MapEntry(key: name, value: body) in {
    'an int user id (criterion 1)': _intUserId,
    'a missing token (criterion 3)': _missingToken,
  }.entries) {
    group('a body with $name', () {
      test('control: the generated parser really throws on it', () {
        expect(() => AuthResponseModel.fromJson(body), throwsA(isA<Error>()));
      });

      test('login returns a ResultFailure and never throws', () async {
        final result = await repositoryFor(body).login('a@b.c', 'pw');

        expect(result, isA<ResultFailure<User>>());
        expect(
          result.failureOrNull,
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            'INVALID_AUTH_RESPONSE',
          ),
        );
        verifyNever(() => local.cacheToken(any()));
      });

      test('register returns a ResultFailure and never throws', () async {
        final result = await repositoryFor(body).register('a@b.c', 'pw', 'A');

        expect(result, isA<ResultFailure<User>>());
        verifyNever(() => local.cacheToken(any()));
      });

      test('criterion 2: AuthNotifier.login ends with isLoading false and an '
          'error', () async {
        final repository = repositoryFor(body);
        final container = ProviderContainer(
          overrides: [
            loginUseCaseProvider.overrideWithValue(LoginUseCase(repository)),
            registerUseCaseProvider.overrideWithValue(
              RegisterUseCase(repository),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(authNotifierProvider.notifier);

        await notifier.login('a@b.c', 'pw');
        final afterLogin = container.read(authNotifierProvider);
        expect(afterLogin.isLoading, isFalse);
        expect(afterLogin.error, isNotNull);
        expect(afterLogin.user, isNull);

        await notifier.register('a@b.c', 'pw', 'A');
        final afterRegister = container.read(authNotifierProvider);
        expect(afterRegister.isLoading, isFalse);
        expect(afterRegister.error, isNotNull);
      });
    });
  }

  test('AuthNotifier.login still stops loading if a use case throws', () async {
    final useCase = _MockLoginUseCase();
    when(() => useCase(any(), any())).thenThrow(StateError('boom'));
    final container = ProviderContainer(
      overrides: [loginUseCaseProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).login('a', 'b');

    final state = container.read(authNotifierProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNotNull);
  });
}
