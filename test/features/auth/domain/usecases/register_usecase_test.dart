import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('RegisterUseCase', () {
    late RegisterUseCase registerUseCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
      registerUseCase = RegisterUseCase(mockRepository);
    });

    test('should return User when registration succeeds', () async {
      // Arrange
      const user = User(
        id: '1',
        email: 'test@example.com',
        name: 'Test User',
      );
      when(
        () => mockRepository.register(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => const Success(user));

      // Act
      final result = await registerUseCase(
        'test@example.com',
        'password123',
        'Test User',
      );

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, user);
      verify(
        () => mockRepository.register(
          'test@example.com',
          'password123',
          'Test User',
        ),
      ).called(1);
    });

    test('should return failure when registration fails', () async {
      // Arrange
      const failure = AuthFailure('Registration failed');
      when(
        () => mockRepository.register(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await registerUseCase(
        'test@example.com',
        'password123',
        'Test User',
      );

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
      verify(
        () => mockRepository.register(
          'test@example.com',
          'password123',
          'Test User',
        ),
      ).called(1);
    });
  });
}
