import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/is_authenticated_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}

class MockGetCurrentUserUseCase extends Mock
    implements GetCurrentUserUseCase {}

class MockIsAuthenticatedUseCase extends Mock
    implements IsAuthenticatedUseCase {}

void main() {
  group('AuthNotifier', () {
    late ProviderContainer container;
    late MockLoginUseCase mockLoginUseCase;
    late MockRegisterUseCase mockRegisterUseCase;
    late MockLogoutUseCase mockLogoutUseCase;
    late MockRefreshTokenUseCase mockRefreshTokenUseCase;
    late MockGetCurrentUserUseCase mockGetCurrentUserUseCase;
    late MockIsAuthenticatedUseCase mockIsAuthenticatedUseCase;

    setUp(() {
      mockLoginUseCase = MockLoginUseCase();
      mockRegisterUseCase = MockRegisterUseCase();
      mockLogoutUseCase = MockLogoutUseCase();
      mockRefreshTokenUseCase = MockRefreshTokenUseCase();
      mockGetCurrentUserUseCase = MockGetCurrentUserUseCase();
      mockIsAuthenticatedUseCase = MockIsAuthenticatedUseCase();

      container = ProviderContainer(
        overrides: [
          loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
          registerUseCaseProvider.overrideWithValue(mockRegisterUseCase),
          logoutUseCaseProvider.overrideWithValue(mockLogoutUseCase),
          refreshTokenUseCaseProvider.overrideWithValue(
            mockRefreshTokenUseCase,
          ),
          getCurrentUserUseCaseProvider.overrideWithValue(
            mockGetCurrentUserUseCase,
          ),
          isAuthenticatedUseCaseProvider.overrideWithValue(
            mockIsAuthenticatedUseCase,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('login', () {
      test('should update state with user on success', () async {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        when(() => mockLoginUseCase(any(), any()))
            .thenAnswer((_) async => const Success(user));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.login('test@example.com', 'password123');

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, user);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        verify(() => mockLoginUseCase('test@example.com', 'password123'))
            .called(1);
      });

      test('should update state with error on failure', () async {
        // Arrange
        const failure = AuthFailure('Login failed');
        when(() => mockLoginUseCase(any(), any()))
            .thenAnswer((_) async => const ResultFailure(failure));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.login('test@example.com', 'password123');

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, isNull);
        expect(state.isLoading, isFalse);
        expect(state.error, 'Login failed');
      });

      test('should set loading state during login', () async {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
        );
        when(() => mockLoginUseCase(any(), any()))
            .thenAnswer((_) async => const Success(user));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        final future = notifier.login('test@example.com', 'password123');

        // Assert - check loading state before completion
        final loadingState = container.read(authNotifierProvider);
        expect(loadingState.isLoading, isTrue);

        await future;

        final finalState = container.read(authNotifierProvider);
        expect(finalState.isLoading, isFalse);
      });
    });

    group('register', () {
      test('should update state with user on success', () async {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        when(
          () => mockRegisterUseCase(any(), any(), any()),
        ).thenAnswer((_) async => const Success(user));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.register(
          'test@example.com',
          'password123',
          'Test User',
        );

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, user);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        verify(
          () => mockRegisterUseCase(
            'test@example.com',
            'password123',
            'Test User',
          ),
        ).called(1);
      });

      test('should update state with error on failure', () async {
        // Arrange
        const failure = AuthFailure('Registration failed');
        when(
          () => mockRegisterUseCase(any(), any(), any()),
        ).thenAnswer((_) async => const ResultFailure(failure));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.register(
          'test@example.com',
          'password123',
          'Test User',
        );

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, isNull);
        expect(state.isLoading, isFalse);
        expect(state.error, 'Registration failed');
      });
    });

    group('logout', () {
      test('should clear user on success', () async {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        when(() => mockLoginUseCase(any(), any()))
            .thenAnswer((_) async => const Success(user));
        when(() => mockLogoutUseCase())
            .thenAnswer((_) async => const Success(null));

        final notifier = container.read(authNotifierProvider.notifier);
        // Set initial user state
        await notifier.login('test@example.com', 'password123');

        // Act
        await notifier.logout();

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, isNull);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        verify(() => mockLogoutUseCase()).called(1);
      });

      test('should handle logout failure', () async {
        // Arrange
        const failure = AuthFailure('Logout failed');
        when(() => mockLogoutUseCase())
            .thenAnswer((_) async => const ResultFailure(failure));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.logout();

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.isLoading, isFalse);
        expect(state.error, 'Logout failed');
      });
    });

    group('refreshToken', () {
      test('should not change state on success', () async {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        when(() => mockLoginUseCase(any(), any()))
            .thenAnswer((_) async => const Success(user));
        when(() => mockRefreshTokenUseCase())
            .thenAnswer((_) async => const Success('new_token'));

        final notifier = container.read(authNotifierProvider.notifier);
        // Set initial state
        await notifier.login('test@example.com', 'password123');

        // Act
        await notifier.refreshToken();

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, isNotNull);
        verify(() => mockRefreshTokenUseCase()).called(1);
      });

      test('should logout on refresh token expiry', () async {
        // Arrange
        const failure = AuthFailure(
          'Refresh token expired',
          code: 'REFRESH_TOKEN_EXPIRED',
        );
        when(() => mockRefreshTokenUseCase())
            .thenAnswer((_) async => const ResultFailure(failure));
        when(() => mockLogoutUseCase())
            .thenAnswer((_) async => const Success(null));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.refreshToken();

        // Assert
        verify(() => mockRefreshTokenUseCase()).called(1);
        verify(() => mockLogoutUseCase()).called(1);
      });
    });

    group('getCurrentUser', () {
      test('should update state with user on success', () async {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );
        when(() => mockGetCurrentUserUseCase())
            .thenAnswer((_) async => const Success(user));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.getCurrentUser();

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, user);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        verify(() => mockGetCurrentUserUseCase()).called(1);
      });

      test('should handle null user', () async {
        // Arrange
        when(() => mockGetCurrentUserUseCase())
            .thenAnswer((_) async => const Success(null));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        await notifier.getCurrentUser();

        // Assert
        final state = container.read(authNotifierProvider);
        expect(state.user, isNull);
        expect(state.isLoading, isFalse);
      });
    });

    group('isAuthenticated', () {
      test('should return true when authenticated', () async {
        // Arrange
        when(() => mockIsAuthenticatedUseCase())
            .thenAnswer((_) async => const Success(true));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        final result = await notifier.isAuthenticated();

        // Assert
        expect(result, isTrue);
        verify(() => mockIsAuthenticatedUseCase()).called(1);
      });

      test('should return false when not authenticated', () async {
        // Arrange
        when(() => mockIsAuthenticatedUseCase())
            .thenAnswer((_) async => const Success(false));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        final result = await notifier.isAuthenticated();

        // Assert
        expect(result, isFalse);
      });

      test('should return false on failure', () async {
        // Arrange
        const failure = AuthFailure('Check failed');
        when(() => mockIsAuthenticatedUseCase())
            .thenAnswer((_) async => const ResultFailure(failure));

        final notifier = container.read(authNotifierProvider.notifier);

        // Act
        final result = await notifier.isAuthenticated();

        // Assert
        expect(result, isFalse);
      });
    });
  });
}
