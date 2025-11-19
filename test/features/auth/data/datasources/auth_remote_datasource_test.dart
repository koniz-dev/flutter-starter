import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_factories.dart';
import '../../../../helpers/test_fixtures.dart';

void main() {
  group('AuthRemoteDataSourceImpl', () {
    late AuthRemoteDataSourceImpl dataSource;
    late MockApiClient mockApiClient;

    setUp(() {
      mockApiClient = createMockApiClient();
      dataSource = AuthRemoteDataSourceImpl(mockApiClient);
    });

    group('login', () {
      test('should return AuthResponseModel when login succeeds', () async {
        // Arrange
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        // Act
        final result = await dataSource.login(
          'test@example.com',
          'password123',
        );

        // Assert
        expect(result, isA<AuthResponseModel>());
        expect(result.user.email, 'test@example.com');
        verify(
          () => mockApiClient.post(
            '/auth/login',
            data: {
              'email': 'test@example.com',
              'password': 'password123',
            },
          ),
        ).called(1);
      });

      test('should throw ServerException on 4xx error', () async {
        // Arrange
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
          data: {'message': 'Invalid credentials'},
        );
        // Create DioException with ServerException in error field
        // (as ErrorInterceptor would do in production)
        const serverException = ServerException(
          'Invalid credentials',
          statusCode: 401,
        );
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.badResponse,
          response: response,
          error: serverException,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenThrow(dioException);

        // Act & Assert
        expect(
          () => dataSource.login(
            'test@example.com',
            'wrongpassword',
          ),
          throwsA(
            predicate<DioException>(
              (e) => e.error is ServerException,
            ),
          ),
        );
      });

      test('should throw NetworkException on network error', () async {
        // Arrange
        // Create DioException with NetworkException in error field
        // (as ErrorInterceptor would do in production)
        const networkException = NetworkException(
          'Connection timeout: Connection timeout',
          code: 'CONNECTION_TIMEOUT',
        );
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
          error: networkException,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenThrow(dioException);

        // Act & Assert
        expect(
          () => dataSource.login(
            'test@example.com',
            'password123',
          ),
          throwsA(
            predicate<DioException>(
              (e) => e.error is NetworkException,
            ),
          ),
        );
      });
    });

    group('register', () {
      test('should return AuthResponseModel when register succeeds', () async {
        // Arrange
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 201,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        // Act
        final result = await dataSource.register(
          'test@example.com',
          'password123',
          'Test User',
        );

        // Assert
        expect(result, isA<AuthResponseModel>());
        verify(
          () => mockApiClient.post(
            '/auth/register',
            data: {
              'email': 'test@example.com',
              'password': 'password123',
              'name': 'Test User',
            },
          ),
        ).called(1);
      });
    });

    group('logout', () {
      test('should complete successfully', () async {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/logout'),
          statusCode: 200,
        );
        when(() => mockApiClient.post(any<String>()))
            .thenAnswer((_) async => response);

        // Act
        await dataSource.logout();

        // Assert
        verify(() => mockApiClient.post('/auth/logout')).called(1);
      });
    });

    group('refreshToken', () {
      test(
        'should return new AuthResponseModel when refresh succeeds',
        () async {
          // Arrange
          final responseData = createAuthResponseJson(
            token: 'new-access-token',
            refreshToken: 'new-refresh-token',
          );
          final response = Response(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            statusCode: 200,
            data: responseData,
          );
          when(
            () => mockApiClient.post(
              any<String>(),
              data: any<dynamic>(named: 'data'),
            ),
          ).thenAnswer((_) async => response);

          // Act
          final result = await dataSource.refreshToken(
            'refresh-token',
          );

          // Assert
          expect(result, isA<AuthResponseModel>());
          expect(result.token, 'new-access-token');
          verify(
            () => mockApiClient.post(
              '/auth/refresh',
              data: {'refresh_token': 'refresh-token'},
            ),
          ).called(1);
        },
      );
    });

    group('Edge Cases', () {
      test('should handle empty email', () async {
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        await dataSource.login('', 'password');
        verify(
          () => mockApiClient.post(
            '/auth/login',
            data: {'email': '', 'password': 'password'},
          ),
        ).called(1);
      });

      test('should handle empty password', () async {
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        await dataSource.login('test@example.com', '');
        verify(
          () => mockApiClient.post(
            '/auth/login',
            data: {'email': 'test@example.com', 'password': ''},
          ),
        ).called(1);
      });

      test('should handle empty name in register', () async {
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 201,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        await dataSource.register('test@example.com', 'password', '');
        verify(
          () => mockApiClient.post(
            '/auth/register',
            data: {
              'email': 'test@example.com',
              'password': 'password',
              'name': '',
            },
          ),
        ).called(1);
      });

      test('should handle long email', () async {
        final longEmail = 'a' * 100 + '@example.com';
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        await dataSource.login(longEmail, 'password');
        verify(
          () => mockApiClient.post(
            '/auth/login',
            data: {'email': longEmail, 'password': 'password'},
          ),
        ).called(1);
      });

      test('should handle long password', () async {
        final longPassword = 'a' * 200;
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        await dataSource.login('test@example.com', longPassword);
        verify(
          () => mockApiClient.post(
            '/auth/login',
            data: {'email': 'test@example.com', 'password': longPassword},
          ),
        ).called(1);
      });

      test('should handle empty refresh token', () async {
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          statusCode: 200,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        await dataSource.refreshToken('');
        verify(
          () => mockApiClient.post(
            '/auth/refresh',
            data: {'refresh_token': ''},
          ),
        ).called(1);
      });

      test('should handle long refresh token', () async {
        final longToken = 'a' * 500;
        final responseData = createAuthResponseJson();
        final response = Response(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          statusCode: 200,
          data: responseData,
        );
        when(
          () => mockApiClient.post(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => response);

        await dataSource.refreshToken(longToken);
        verify(
          () => mockApiClient.post(
            '/auth/refresh',
            data: {'refresh_token': longToken},
          ),
        ).called(1);
      });
    });
  });
}
