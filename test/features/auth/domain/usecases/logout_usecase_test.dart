import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_factories.dart';
import '../../../../helpers/test_fixtures.dart';

void main() {
  group('LogoutUseCase', () {
    late LogoutUseCase logoutUseCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = createMockAuthRepository();
      logoutUseCase = LogoutUseCase(mockRepository);
    });

    test('should return Success when logout succeeds', () async {
      // Arrange
      when(
        () => mockRepository.logout(),
      ).thenAnswer((_) async => const Success(null));

      // Act
      final result = await logoutUseCase();

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.logout()).called(1);
    });

    test('should return Failure when logout fails', () async {
      // Arrange
      final failure = createServerFailure(message: 'Logout failed');
      when(
        () => mockRepository.logout(),
      ).thenAnswer((_) async => ResultFailure(failure));

      // Act
      final result = await logoutUseCase();

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
      verify(() => mockRepository.logout()).called(1);
    });

    test('should delegate to repository', () async {
      // Arrange
      when(
        () => mockRepository.logout(),
      ).thenAnswer((_) async => const Success(null));

      // Act
      await logoutUseCase();

      // Assert
      verify(() => mockRepository.logout()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
