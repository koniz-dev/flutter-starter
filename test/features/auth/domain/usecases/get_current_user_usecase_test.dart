import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_factories.dart';
import '../../../../helpers/test_fixtures.dart';

void main() {
  group('GetCurrentUserUseCase', () {
    late GetCurrentUserUseCase getCurrentUserUseCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = createMockAuthRepository();
      getCurrentUserUseCase = GetCurrentUserUseCase(mockRepository);
    });

    test('should return User when user is cached', () async {
      // Arrange
      final user = createUser();
      when(
        () => mockRepository.getCurrentUser(),
      ).thenAnswer((_) async => Success(user));

      // Act
      final result = await getCurrentUserUseCase();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, user);
      verify(() => mockRepository.getCurrentUser()).called(1);
    });

    test('should return null User when no user is cached', () async {
      // Arrange
      when(
        () => mockRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Success(null));

      // Act
      final result = await getCurrentUserUseCase();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
      verify(() => mockRepository.getCurrentUser()).called(1);
    });

    test('should return Failure when getCurrentUser fails', () async {
      // Arrange
      final failure = createCacheFailure(message: 'Failed to get cached user');
      when(
        () => mockRepository.getCurrentUser(),
      ).thenAnswer((_) async => ResultFailure(failure));

      // Act
      final result = await getCurrentUserUseCase();

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
      verify(() => mockRepository.getCurrentUser()).called(1);
    });

    test('should delegate to repository', () async {
      // Arrange
      final user = createUser();
      when(
        () => mockRepository.getCurrentUser(),
      ).thenAnswer((_) async => Success(user));

      // Act
      await getCurrentUserUseCase();

      // Assert
      verify(() => mockRepository.getCurrentUser()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
