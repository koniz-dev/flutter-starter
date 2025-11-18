import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/usecases/is_authenticated_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_factories.dart';
import '../../../../helpers/test_fixtures.dart';

void main() {
  group('IsAuthenticatedUseCase', () {
    late IsAuthenticatedUseCase isAuthenticatedUseCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = createMockAuthRepository();
      isAuthenticatedUseCase = IsAuthenticatedUseCase(mockRepository);
    });

    test('should return true when user is authenticated', () async {
      // Arrange
      when(() => mockRepository.isAuthenticated())
          .thenAnswer((_) async => const Success(true));

      // Act
      final result = await isAuthenticatedUseCase();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isTrue);
      verify(() => mockRepository.isAuthenticated()).called(1);
    });

    test('should return false when user is not authenticated', () async {
      // Arrange
      when(() => mockRepository.isAuthenticated())
          .thenAnswer((_) async => const Success(false));

      // Act
      final result = await isAuthenticatedUseCase();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
      verify(() => mockRepository.isAuthenticated()).called(1);
    });

    test('should return Failure when check fails', () async {
      // Arrange
      final failure = createCacheFailure(
        message: 'Failed to check authentication',
      );
      when(() => mockRepository.isAuthenticated())
          .thenAnswer((_) async => ResultFailure(failure));

      // Act
      final result = await isAuthenticatedUseCase();

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
      verify(() => mockRepository.isAuthenticated()).called(1);
    });

    test('should delegate to repository', () async {
      // Arrange
      when(() => mockRepository.isAuthenticated())
          .thenAnswer((_) async => const Success(true));

      // Act
      await isAuthenticatedUseCase();

      // Assert
      verify(() => mockRepository.isAuthenticated()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
