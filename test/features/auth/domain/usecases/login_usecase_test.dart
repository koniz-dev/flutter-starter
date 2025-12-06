import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('LoginUseCase', () {
    late LoginUseCase loginUseCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
      loginUseCase = LoginUseCase(mockRepository);
    });

    test('should return User when login succeeds', () async {
      // Arrange
      const user = User(
        id: '1',
        email: 'test@example.com',
        name: 'Test User',
      );
      when(
        () => mockRepository.login(any(), any()),
      ).thenAnswer((_) async => const Success(user));

      // Act
      final result = await loginUseCase('test@example.com', 'password123');

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, user);
      verify(
        () => mockRepository.login('test@example.com', 'password123'),
      ).called(1);
    });

    test('should return failure when login fails', () async {
      // Arrange
      const failure = AuthFailure('Invalid credentials');
      when(
        () => mockRepository.login(any(), any()),
      ).thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await loginUseCase('test@example.com', 'wrongpassword');

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
      verify(
        () => mockRepository.login('test@example.com', 'wrongpassword'),
      ).called(1);
    });

    test('should delegate to repository with correct parameters', () async {
      // Arrange
      const user = User(
        id: '1',
        email: 'test@example.com',
      );
      when(
        () => mockRepository.login(any(), any()),
      ).thenAnswer((_) async => const Success(user));

      // Act
      await loginUseCase('test@example.com', 'password123');

      // Assert
      verify(
        () => mockRepository.login('test@example.com', 'password123'),
      ).called(1);
      verifyNever(() => mockRepository.login('other@example.com', any()));
    });
  });
}
