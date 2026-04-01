import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/network/adapters/dio_network_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  group('DioNetworkClient', () {
    late DioNetworkClient client;
    late _MockDio dio;

    setUp(() {
      dio = _MockDio();
      client = DioNetworkClient(dio);
    });

    test(
      'should map NetworkRequest to dio.request and return NetworkResponse',
      () async {
        const request = NetworkRequest(
          path: '/x',
          method: NetworkMethod.post,
          body: {'a': 1},
          headers: {'h': 'v'},
          queryParameters: {'q': '1'},
          timeout: Duration(seconds: 2),
        );

        final response = Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: {'ok': true},
          headers: Headers.fromMap(const {
            'k': ['v'],
          }),
        );

        when(
          () => dio.request<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            queryParameters: any<Map<String, dynamic>>(
              named: 'queryParameters',
            ),
            options: any<Options>(named: 'options'),
          ),
        ).thenAnswer((inv) async {
          final path = inv.positionalArguments[0] as String;
          expect(path, '/x');

          final options = inv.namedArguments[#options] as Options;
          expect(options.method, 'POST');
          expect(options.headers, request.headers);
          expect(options.sendTimeout, request.timeout);
          expect(options.receiveTimeout, request.timeout);

          expect(inv.namedArguments[#data], request.body);
          expect(inv.namedArguments[#queryParameters], request.queryParameters);
          return response;
        });

        final result = await client.send(request);

        expect(result.statusCode, 201);
        expect(result.data, {'ok': true});
        expect(result.headers, response.headers.map);
      },
    );

    test(
      'should rethrow app exception when DioException.error is an Exception',
      () async {
        const request = NetworkRequest(
          path: '/x',
          method: NetworkMethod.get,
        );

        // DioNetworkClient only rethrows when DioException.error is an
        // Exception (not an Error like StateError/ArgumentError).
        const appException = FormatException('boom');
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/x'),
          error: appException,
        );

        when(
          () => dio.request<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            queryParameters: any<Map<String, dynamic>>(
              named: 'queryParameters',
            ),
            options: any<Options>(named: 'options'),
          ),
        ).thenThrow(dioException);

        expect(() => client.send(request), throwsA(same(appException)));
      },
    );

    test(
      'should wrap DioException into NetworkError when error is not Exception',
      () async {
        const request = NetworkRequest(
          path: '/x',
          method: NetworkMethod.get,
        );

        final dioException = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
          message: 'no internet',
        );

        when(
          () => dio.request<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            queryParameters: any<Map<String, dynamic>>(
              named: 'queryParameters',
            ),
            options: any<Options>(named: 'options'),
          ),
        ).thenThrow(dioException);

        await expectLater(
          client.send(request),
          throwsA(
            isA<NetworkError>()
                .having((e) => e.message, 'message', 'no internet')
                .having(
                  (e) => e.code,
                  'code',
                  DioExceptionType.connectionError.name,
                ),
          ),
        );
      },
    );
  });
}
