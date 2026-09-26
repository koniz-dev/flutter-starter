import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class FakeUserModel extends Fake implements UserModel {}

/// Counts its own teardown call, so a step that follows a *failing* step can
/// be asserted to have run rather than merely to have been wired up.
///
/// Optionally throws, to cover the mirror case: the last step failing must
/// still be reported to the caller.
class _RecordingHttpCache implements IHttpResponseCache {
  _RecordingHttpCache({this.thrown});

  /// Thrown by [clearCache] after the call is counted, when non-null.
  final Object? thrown;

  int clearCalls = 0;

  @override
  Future<void> clearCache() async {
    clearCalls++;
    final failure = thrown;
    if (failure != null) {
      // Typed `Object` on purpose: the point of these cases is that the
      // teardown must survive an `Error` as well as an `Exception`, so the
      // lint's premise does not hold here.
      // ignore: only_throw_errors
      throw failure;
    }
  }
}

/// One injected teardown failure: what to throw and what the caller should be
/// told about it.
typedef _ThrownCase = ({String label, Object thrown, String expectedMessage});

/// `on Exception` was half the defect (#168): an [Error] thrown by a teardown
/// step escaped raw *and* skipped the step after it, so every independence
/// assertion has to be made for both.
final _thrownCases = <_ThrownCase>[
  (
    label: 'an Exception',
    thrown: const CacheException('Keychain locked'),
    expectedMessage: 'Keychain locked',
  ),
  (
    label: 'an Error',
    thrown: StateError('prefs plugin missing'),
    expectedMessage: 'prefs plugin missing',
  ),
];

void main() {
  group('AuthRepositoryImpl', () {
    late AuthRepositoryImpl repository;
    late MockAuthRemoteDataSource mockRemoteDataSource;
    late MockAuthLocalDataSource mockLocalDataSource;

    setUpAll(() {
      registerFallbackValue(FakeUserModel());
    });

    setUp(() {
      mockRemoteDataSource = MockAuthRemoteDataSource();
      mockLocalDataSource = MockAuthLocalDataSource();
      repository = AuthRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
      );
    });

    group('login', () {
      test('should return User when login succeeds', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'access_token',
          refreshToken: 'refresh_token',
        );
        when(
          () => mockRemoteDataSource.login(any(), any()),
        ).thenAnswer((_) async => authResponse);
        when(
          () => mockLocalDataSource.cacheUser(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheRefreshToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.login('test@example.com', 'password');

        // Assert
        expect(result.isSuccess, isTrue);
        final user = result.dataOrNull;
        expect(user, isNotNull);
        expect(user?.id, '1');
        expect(user?.email, 'test@example.com');
        verify(
          () => mockRemoteDataSource.login('test@example.com', 'password'),
        ).called(1);
        verify(() => mockLocalDataSource.cacheUser(userModel)).called(1);
        verify(() => mockLocalDataSource.cacheToken('access_token')).called(1);
        verify(
          () => mockLocalDataSource.cacheRefreshToken('refresh_token'),
        ).called(1);
      });

      test('should return ServerFailure when remote data source '
          'throws ServerException', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.login(any(), any()),
        ).thenThrow(const ServerException('Server error', code: '500'));

        // Act
        final result = await repository.login('test@example.com', 'password');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<ServerFailure>());
        expect(failure?.message, 'Server error');
        expect(failure?.code, '500');
        verify(
          () => mockRemoteDataSource.login('test@example.com', 'password'),
        ).called(1);
        verifyNever(() => mockLocalDataSource.cacheUser(any()));
      });

      test('should return NetworkFailure when remote data source '
          'throws NetworkException', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.login(any(), any()),
        ).thenThrow(const NetworkException('Network error'));
        when(
          () => mockLocalDataSource.cacheUser(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.login('test@example.com', 'password');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<NetworkFailure>());
        expect(failure?.message, 'Network error');
      });

      // koniz-dev/flutter-starter#181: the forced-logout decision now reads
      // `failure.code` alone, so the layer that knows what the round trip
      // meant has to say so. These three pin which outcomes carry the tag.
      test(
        'should tag a missing refresh token as REFRESH_TOKEN_EXPIRED',
        () async {
          // Arrange
          when(
            () => mockLocalDataSource.getRefreshToken(),
          ).thenAnswer((_) async => null);

          // Act
          final result = await repository.refreshToken();

          // Assert
          expect(
            result.failureOrNull?.code,
            AuthErrorCodes.refreshTokenExpired,
          );
        },
      );

      test(
        'should tag a 401 from the refresh endpoint as REFRESH_TOKEN_EXPIRED',
        () async {
          // Arrange: the default 401 message carries no "refresh" substring,
          // so the pre-#181 message match never reached this case at all.
          when(
            () => mockLocalDataSource.getRefreshToken(),
          ).thenAnswer((_) async => 'refresh_token');
          when(() => mockRemoteDataSource.refreshToken(any())).thenThrow(
            const ServerException(
              'Unauthorized. Please login again.',
              statusCode: 401,
            ),
          );

          // Act
          final result = await repository.refreshToken();

          // Assert
          final failure = result.failureOrNull;
          expect(failure, isA<AuthFailure>());
          expect(failure?.code, AuthErrorCodes.refreshTokenExpired);
          expect(failure?.message, 'Unauthorized. Please login again.');
        },
      );

      test(
        'should not tag a transport failure as REFRESH_TOKEN_EXPIRED',
        () async {
          // Arrange
          when(
            () => mockLocalDataSource.getRefreshToken(),
          ).thenAnswer((_) async => 'refresh_token');
          when(() => mockRemoteDataSource.refreshToken(any())).thenThrow(
            const ServerException(
              'Service unavailable. Please try again later.',
              statusCode: 503,
            ),
          );

          // Act
          final result = await repository.refreshToken();

          // Assert
          final failure = result.failureOrNull;
          expect(failure, isA<ServerFailure>());
          expect(failure?.code, isNot(AuthErrorCodes.refreshTokenExpired));
        },
      );

      test('should cache refresh token only if provided', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'access_token',
          // refreshToken is null
        );
        when(
          () => mockRemoteDataSource.login(any(), any()),
        ).thenAnswer((_) async => authResponse);
        when(
          () => mockLocalDataSource.cacheUser(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        await repository.login('test@example.com', 'password');

        // Assert
        verifyNever(() => mockLocalDataSource.cacheRefreshToken(any()));
      });
    });

    group('register', () {
      test('should return User when registration succeeds', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'access_token',
        );
        when(
          () => mockRemoteDataSource.register(any(), any(), any()),
        ).thenAnswer((_) async => authResponse);
        when(
          () => mockLocalDataSource.cacheUser(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.register(
          'test@example.com',
          'password',
          'Test User',
        );

        // Assert
        expect(result.isSuccess, isTrue);
        final user = result.dataOrNull;
        expect(user, isNotNull);
        expect(user?.email, 'test@example.com');
        verify(
          () => mockRemoteDataSource.register(
            'test@example.com',
            'password',
            'Test User',
          ),
        ).called(1);
      });

      test('should return failure when registration fails', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.register(any(), any(), any()),
        ).thenThrow(const ServerException('Registration failed'));
        when(
          () => mockLocalDataSource.cacheUser(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.register(
          'test@example.com',
          'password',
          'Test User',
        );

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ServerFailure>());
      });
    });

    group('logout', () {
      test('should return success when logout succeeds', () async {
        // Arrange
        when(() => mockRemoteDataSource.logout()).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.clearCache(),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockRemoteDataSource.logout()).called(1);
        verify(() => mockLocalDataSource.clearCache()).called(1);
      });

      // Regression for #52. This test predates the fix and set up exactly
      // this scenario, but asserted only on the Result - so it passed while
      // clearCache() was never reached and the tokens stayed on the device.
      // The two verify() calls are the assertions it was missing.
      test('should return failure when logout fails', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.logout(),
        ).thenThrow(const NetworkException('Network error'));
        when(
          () => mockLocalDataSource.clearCache(),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<NetworkFailure>());
        verify(() => mockRemoteDataSource.logout()).called(1);
        verify(() => mockLocalDataSource.clearCache()).called(1);
      });

      test('should clear the local session when the remote call times '
          'out', () async {
        // Arrange - what an offline device or an unreachable host produces.
        when(() => mockRemoteDataSource.logout()).thenAnswer((_) async {
          throw DioException.connectionTimeout(
            timeout: const Duration(seconds: 30),
            requestOptions: RequestOptions(path: '/auth/logout'),
          );
        });
        when(
          () => mockLocalDataSource.clearCache(),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isFailure, isTrue);
        verify(() => mockLocalDataSource.clearCache()).called(1);
      });

      test('should clear the local session when the remote call throws an '
          'Error', () async {
        // Arrange - an Error is not an Exception, so the pre-fix `on Exception`
        // chain did not even convert it to a Result: it escaped the repository.
        when(
          () => mockRemoteDataSource.logout(),
        ).thenThrow(StateError('plugin missing'));
        when(
          () => mockLocalDataSource.clearCache(),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
        expect(result.failureOrNull?.code, 'UNKNOWN_ERROR');
        verify(() => mockLocalDataSource.clearCache()).called(1);
      });

      // Pins the documented precedence: when both sides fail, the caller is
      // told about the local one, because that is the state still on the
      // device.
      test('should report the local failure when the teardown also '
          'fails', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.logout(),
        ).thenThrow(const NetworkException('Network error'));
        when(
          () => mockLocalDataSource.clearCache(),
        ).thenThrow(const CacheException('Keychain locked'));

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<CacheFailure>());
        expect(result.failureOrNull?.message, 'Keychain locked');
      });

      // Regression for koniz-dev/flutter-starter#168 criteria 1 and 3.
      //
      // The two local teardown steps used to share one `try`, so the first to
      // throw skipped the second: every `http_cache_*` body survived a logout
      // the user had explicitly asked for. `AuthInterceptor._logoutUser()`
      // guards each of its steps separately; these pin the explicit path to
      // the same rule.
      //
      // Counterfactual, actually run
      // (docs/verification/issue-168/counterfactual.log): against the chained
      // pre-fix body both cases below fail on `httpCache.clearCalls`, which is
      // 0 rather than 1.
      group('local teardown steps are independent (#168)', () {
        for (final failure in _thrownCases) {
          test(
            'a local teardown throwing ${failure.label} must not skip the '
            'HTTP cache',
            () async {
              // Arrange
              final httpCache = _RecordingHttpCache();
              final repositoryWithCache = AuthRepositoryImpl(
                remoteDataSource: mockRemoteDataSource,
                localDataSource: mockLocalDataSource,
                httpCache: httpCache,
              );
              when(
                () => mockRemoteDataSource.logout(),
              ).thenAnswer((_) async => {});
              when(
                () => mockLocalDataSource.clearCache(),
              ).thenThrow(failure.thrown);

              // Act
              final result = await repositoryWithCache.logout();

              // Assert - the step after the failing one still ran, exactly
              // once.
              expect(
                httpCache.clearCalls,
                1,
                reason:
                    'cached bodies must not outlive a logout just because '
                    'the step before this one threw',
              );
              // ...and the caller is still told the teardown failed.
              expect(result.isFailure, isTrue);
              expect(
                result.failureOrNull?.message,
                contains(failure.expectedMessage),
              );
            },
          );

          test(
            'an HTTP cache throwing ${failure.label} is still reported after '
            'a clean local teardown',
            () async {
              // Arrange - the mirror case: the *last* step failing must not be
              // swallowed into a Success.
              final httpCache = _RecordingHttpCache(thrown: failure.thrown);
              final repositoryWithCache = AuthRepositoryImpl(
                remoteDataSource: mockRemoteDataSource,
                localDataSource: mockLocalDataSource,
                httpCache: httpCache,
              );
              when(
                () => mockRemoteDataSource.logout(),
              ).thenAnswer((_) async => {});
              when(
                () => mockLocalDataSource.clearCache(),
              ).thenAnswer((_) async => {});

              // Act
              final result = await repositoryWithCache.logout();

              // Assert
              verify(() => mockLocalDataSource.clearCache()).called(1);
              expect(httpCache.clearCalls, 1);
              expect(result.isFailure, isTrue);
              expect(
                result.failureOrNull?.message,
                contains(failure.expectedMessage),
              );
            },
          );
        }

        test(
          'when both local steps fail the first failure is the one reported',
          () async {
            // Arrange
            final httpCache = _RecordingHttpCache(
              thrown: StateError('cache backend unavailable'),
            );
            final repositoryWithCache = AuthRepositoryImpl(
              remoteDataSource: mockRemoteDataSource,
              localDataSource: mockLocalDataSource,
              httpCache: httpCache,
            );
            when(
              () => mockRemoteDataSource.logout(),
            ).thenAnswer((_) async => {});
            when(
              () => mockLocalDataSource.clearCache(),
            ).thenThrow(const CacheException('Keychain locked'));

            // Act
            final result = await repositoryWithCache.logout();

            // Assert - both steps ran; the first failure is what surfaces.
            expect(httpCache.clearCalls, 1);
            expect(result.failureOrNull, isA<CacheFailure>());
            expect(result.failureOrNull?.message, 'Keychain locked');
          },
        );

        test(
          'a local teardown failure outranks a remote failure',
          () async {
            // Arrange - pins the documented precedence now that the local
            // branch no longer returns early.
            final httpCache = _RecordingHttpCache();
            final repositoryWithCache = AuthRepositoryImpl(
              remoteDataSource: mockRemoteDataSource,
              localDataSource: mockLocalDataSource,
              httpCache: httpCache,
            );
            when(
              () => mockRemoteDataSource.logout(),
            ).thenThrow(const NetworkException('Network error'));
            when(
              () => mockLocalDataSource.clearCache(),
            ).thenThrow(const CacheException('Keychain locked'));

            // Act
            final result = await repositoryWithCache.logout();

            // Assert
            expect(httpCache.clearCalls, 1);
            expect(result.failureOrNull, isA<CacheFailure>());
            expect(result.failureOrNull?.message, 'Keychain locked');
          },
        );
      });
    });

    group('getCurrentUser', () {
      test('should return User when a token and a cached user exist', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'tk');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => userModel);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isSuccess, isTrue);
        final user = result.dataOrNull;
        expect(user, isNotNull);
        expect(user?.id, '1');
        expect(user?.email, 'test@example.com');
      });

      test('should return null User when no cached user', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'tk');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      // Regression for #85: the cold-start restore reads this method, so a
      // cached user with no token here is what booted a credential-less
      // device straight into the authenticated shell.
      test('should return null User when the token is gone but the user blob '
          'survives', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => null);
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => userModel);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('should return null User when the stored token is empty', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        when(() => mockLocalDataSource.getToken()).thenAnswer((_) async => '');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => userModel);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('should not read the user blob at all without a token', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
        verifyNever(() => mockLocalDataSource.getCachedUser());
      });

      // #85 criterion 2: an unreadable token store must surface as a modelled
      // failure, not an escaping throw on the boot path.
      test('should return failure when the token store throws', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenThrow(const CacheException('Failed to get token: keychain'));

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<CacheFailure>());
      });

      test('should return failure when cache read fails', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'tk');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenThrow(const CacheException('Cache error'));

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<CacheFailure>());
      });
    });

    group('isAuthenticated', () {
      test('should return true when a token and a cached user exist', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'tk');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => userModel);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isTrue);
      });

      test('should return false when no cached user', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'tk');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isFalse);
      });

      // Regression for #52 criterion 5: AuthInterceptor's forced logout clears
      // tokens, and reading the user blob alone reported that as a live
      // session.
      test('should return false when the token is gone but the user blob '
          'survives', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => null);
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => userModel);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isFalse);
      });

      test('should return false when the stored token is empty', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        when(() => mockLocalDataSource.getToken()).thenAnswer((_) async => '');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenAnswer((_) async => userModel);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isFalse);
      });

      // #85 criterion 4: the guard and the boot path must answer the same
      // question. Every storage combination, one predicate.
      test('should agree with getCurrentUser on every storage state', () async {
        const userModel = UserModel(id: '1', email: 'test@example.com');
        const cases = <(String?, UserModel?)>[
          ('tk', userModel),
          ('tk', null),
          (null, userModel),
          ('', userModel),
          (null, null),
        ];

        for (final (token, user) in cases) {
          when(
            () => mockLocalDataSource.getToken(),
          ).thenAnswer((_) async => token);
          when(
            () => mockLocalDataSource.getCachedUser(),
          ).thenAnswer((_) async => user);

          final authenticated = await repository.isAuthenticated();
          final current = await repository.getCurrentUser();

          expect(
            authenticated.dataOrNull,
            current.dataOrNull != null,
            reason: 'token=$token user=${user?.id} disagreed',
          );
        }
      });

      test('should propagate a token store failure', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenThrow(const CacheException('Failed to get token: keychain'));

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<CacheFailure>());
      });
    });

    group('refreshToken', () {
      test('should return new token when refresh succeeds', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'new_access_token',
          refreshToken: 'new_refresh_token',
        );
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'old_refresh_token');
        when(
          () => mockRemoteDataSource.refreshToken(any()),
        ).thenAnswer((_) async => authResponse);
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheRefreshToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.refreshToken();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, 'new_access_token');
        verify(
          () => mockLocalDataSource.cacheToken('new_access_token'),
        ).called(1);
        verify(
          () => mockLocalDataSource.cacheRefreshToken('new_refresh_token'),
        ).called(1);
      });

      test(
        'should return UnknownFailure when no refresh token available',
        () async {
          // Arrange
          when(
            () => mockLocalDataSource.getRefreshToken(),
          ).thenAnswer((_) async => null);

          // Act
          final result = await repository.refreshToken();

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result.failureOrNull;
          expect(failure, isA<UnknownFailure>());
          expect(failure?.message, 'No refresh token available');
        },
      );

      test('should return failure when refresh fails', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh_token');
        when(
          () => mockRemoteDataSource.refreshToken(any()),
        ).thenThrow(const AuthException('Token expired'));
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheRefreshToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.refreshToken();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<AuthFailure>());
      });

      test('should cache refresh token only if provided', () async {
        // Arrange
        const userModel = UserModel(id: '1', email: 'test@example.com');
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'new_access_token',
          // refreshToken is null
        );
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'old_refresh_token');
        when(
          () => mockRemoteDataSource.refreshToken(any()),
        ).thenAnswer((_) async => authResponse);
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        await repository.refreshToken();

        // Assert
        verifyNever(() => mockLocalDataSource.cacheRefreshToken(any()));
      });
    });

    group('Edge Cases', () {
      test('register should cache refresh token when provided', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'access_token',
          refreshToken: 'refresh_token',
        );
        when(
          () => mockRemoteDataSource.register(any(), any(), any()),
        ).thenAnswer((_) async => authResponse);
        when(
          () => mockLocalDataSource.cacheUser(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheToken(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockLocalDataSource.cacheRefreshToken(any()),
        ).thenAnswer((_) async => {});

        // Act
        await repository.register('test@example.com', 'password', 'Test User');

        // Assert
        verify(
          () => mockLocalDataSource.cacheRefreshToken('refresh_token'),
        ).called(1);
      });

      test('login should handle generic Exception', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.login(any(), any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.login('test@example.com', 'password');

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('register should handle generic Exception', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.register(any(), any(), any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.register(
          'test@example.com',
          'password',
          'Test User',
        );

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('logout should handle generic Exception', () async {
        // Arrange
        when(
          () => mockRemoteDataSource.logout(),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('getCurrentUser should handle generic Exception', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'tk');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('isAuthenticated should handle generic Exception', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'tk');
        when(
          () => mockLocalDataSource.getCachedUser(),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('refreshToken should handle generic Exception', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh_token');
        when(
          () => mockRemoteDataSource.refreshToken(any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.refreshToken();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });
    });
  });
}
