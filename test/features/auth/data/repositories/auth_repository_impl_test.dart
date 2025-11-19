import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class FakeUserModel extends Fake implements UserModel {}

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
        when(() => mockRemoteDataSource.login(any(), any()))
            .thenAnswer((_) async => authResponse);
        when(() => mockLocalDataSource.cacheUser(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheRefreshToken(any()))
            .thenAnswer((_) async => {});

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
        verify(() => mockLocalDataSource.cacheRefreshToken('refresh_token'))
            .called(1);
      });

      test(
        'should return ServerFailure when remote data source '
        'throws ServerException',
        () async {
          // Arrange
          when(() => mockRemoteDataSource.login(any(), any()))
              .thenThrow(const ServerException('Server error', code: '500'));

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
        },
      );

      test(
        'should return NetworkFailure when remote data source '
        'throws NetworkException',
        () async {
          // Arrange
          when(() => mockRemoteDataSource.login(any(), any()))
              .thenThrow(const NetworkException('Network error'));
          when(() => mockLocalDataSource.cacheUser(any()))
              .thenAnswer((_) async => {});
          when(() => mockLocalDataSource.cacheToken(any()))
              .thenAnswer((_) async => {});

          // Act
          final result = await repository.login('test@example.com', 'password');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result.failureOrNull;
          expect(failure, isA<NetworkFailure>());
          expect(failure?.message, 'Network error');
        },
      );

      test('should cache refresh token only if provided', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
        );
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'access_token',
          // refreshToken is null
        );
        when(() => mockRemoteDataSource.login(any(), any()))
            .thenAnswer((_) async => authResponse);
        when(() => mockLocalDataSource.cacheUser(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});

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
        when(() => mockRemoteDataSource.register(any(), any(), any()))
            .thenAnswer((_) async => authResponse);
        when(() => mockLocalDataSource.cacheUser(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});

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
        when(() => mockRemoteDataSource.register(any(), any(), any()))
            .thenThrow(const ServerException('Registration failed'));
        when(() => mockLocalDataSource.cacheUser(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});

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
        when(() => mockLocalDataSource.clearCache())
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockRemoteDataSource.logout()).called(1);
        verify(() => mockLocalDataSource.clearCache()).called(1);
      });

      test('should return failure when logout fails', () async {
        // Arrange
        when(() => mockRemoteDataSource.logout())
            .thenThrow(const NetworkException('Network error'));
        when(() => mockLocalDataSource.clearCache())
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<NetworkFailure>());
      });
    });

    group('getCurrentUser', () {
      test('should return User when cached user exists', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        when(() => mockLocalDataSource.getCachedUser())
            .thenAnswer((_) async => userModel);

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
        when(() => mockLocalDataSource.getCachedUser())
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('should return failure when cache read fails', () async {
        // Arrange
        when(() => mockLocalDataSource.getCachedUser())
            .thenThrow(const CacheException('Cache error'));

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<CacheFailure>());
      });
    });

    group('isAuthenticated', () {
      test('should return true when cached user exists', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
        );
        when(() => mockLocalDataSource.getCachedUser())
            .thenAnswer((_) async => userModel);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isTrue);
      });

      test('should return false when no cached user', () async {
        // Arrange
        when(() => mockLocalDataSource.getCachedUser())
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isFalse);
      });
    });

    group('refreshToken', () {
      test('should return new token when refresh succeeds', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
        );
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'new_access_token',
          refreshToken: 'new_refresh_token',
        );
        when(() => mockLocalDataSource.getRefreshToken())
            .thenAnswer((_) async => 'old_refresh_token');
        when(() => mockRemoteDataSource.refreshToken(any()))
            .thenAnswer((_) async => authResponse);
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheRefreshToken(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.refreshToken();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, 'new_access_token');
        verify(() => mockLocalDataSource.cacheToken('new_access_token'))
            .called(1);
        verify(() => mockLocalDataSource.cacheRefreshToken('new_refresh_token'))
            .called(1);
      });

      test(
        'should return UnknownFailure when no refresh token available',
        () async {
          // Arrange
          when(() => mockLocalDataSource.getRefreshToken())
              .thenAnswer((_) async => null);

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
        when(() => mockLocalDataSource.getRefreshToken())
            .thenAnswer((_) async => 'refresh_token');
        when(() => mockRemoteDataSource.refreshToken(any()))
            .thenThrow(const AuthException('Token expired'));
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheRefreshToken(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.refreshToken();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<AuthFailure>());
      });

      test('should cache refresh token only if provided', () async {
        // Arrange
        const userModel = UserModel(
          id: '1',
          email: 'test@example.com',
        );
        const authResponse = AuthResponseModel(
          user: userModel,
          token: 'new_access_token',
          // refreshToken is null
        );
        when(() => mockLocalDataSource.getRefreshToken())
            .thenAnswer((_) async => 'old_refresh_token');
        when(() => mockRemoteDataSource.refreshToken(any()))
            .thenAnswer((_) async => authResponse);
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});

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
        when(() => mockRemoteDataSource.register(any(), any(), any()))
            .thenAnswer((_) async => authResponse);
        when(() => mockLocalDataSource.cacheUser(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheToken(any()))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.cacheRefreshToken(any()))
            .thenAnswer((_) async => {});

        // Act
        await repository.register('test@example.com', 'password', 'Test User');

        // Assert
        verify(() => mockLocalDataSource.cacheRefreshToken('refresh_token'))
            .called(1);
      });

      test('login should handle generic Exception', () async {
        // Arrange
        when(() => mockRemoteDataSource.login(any(), any()))
            .thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.login('test@example.com', 'password');

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('register should handle generic Exception', () async {
        // Arrange
        when(() => mockRemoteDataSource.register(any(), any(), any()))
            .thenThrow(Exception('Generic error'));

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
        when(() => mockRemoteDataSource.logout())
            .thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.logout();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('getCurrentUser should handle generic Exception', () async {
        // Arrange
        when(() => mockLocalDataSource.getCachedUser())
            .thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('isAuthenticated should handle generic Exception', () async {
        // Arrange
        when(() => mockLocalDataSource.getCachedUser())
            .thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });

      test('refreshToken should handle generic Exception', () async {
        // Arrange
        when(() => mockLocalDataSource.getRefreshToken())
            .thenAnswer((_) async => 'refresh_token');
        when(() => mockRemoteDataSource.refreshToken(any()))
            .thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.refreshToken();

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
      });
    });
  });
}
