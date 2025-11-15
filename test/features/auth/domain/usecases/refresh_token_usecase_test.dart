import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_factories.dart';
import '../../../../helpers/test_fixtures.dart';

void main() {
  group('RefreshTokenUseCase', () {
    late RefreshTokenUseCase refreshTokenUseCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = createMockAuthRepository();
      refreshTokenUseCase = RefreshTokenUseCase(mockRepository);
    });

    test('should return new token when refresh succeeds', () async {
      // Arrange
      const newToken = 'new-access-token';
      when(() => mockRepository.refreshToken())
          .thenAnswer((_) async => const Success(newToken));

      // Act
      final result = await refreshTokenUseCase();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, newToken);
      verify(() => mockRepository.refreshToken()).called(1);
    });

    test('should return Failure when refresh fails', () async {
      // Arrange
      final failure = createAuthFailure(message: 'Refresh token expired');
      when(() => mockRepository.refreshToken())
          .thenAnswer((_) async => ResultFailure(failure));

      // Act
      final result = await refreshTokenUseCase();

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
      verify(() => mockRepository.refreshToken()).called(1);
    });

    test('should delegate to repository', () async {
      // Arrange
      const newToken = 'new-access-token';
      when(() => mockRepository.refreshToken())
          .thenAnswer((_) async => const Success(newToken));

      // Act
      await refreshTokenUseCase();

      // Assert
      verify(() => mockRepository.refreshToken()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
