import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snippetcheck/http_network_client.dart';

const _get = NetworkRequest(path: '/items', method: NetworkMethod.get);

void main() {
  test('a 500 surfaces as ServerException with its status, not NetworkException', () async {
    final client = HttpNetworkClient(
      MockClient((_) async => http.Response('{"error":"boom"}', 500)),
      baseUrl: 'https://api.example.test/v1',
    );
    await expectLater(
      client.send(_get),
      throwsA(isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500)),
    );
  });

  test('a 404 surfaces as ServerException(404)', () async {
    final client = HttpNetworkClient(
      MockClient((_) async => http.Response('', 404)),
      baseUrl: 'https://api.example.test/v1',
    );
    await expectLater(
      client.send(_get),
      throwsA(isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('a transport failure surfaces as NetworkException CONNECTION_ERROR', () async {
    final client = HttpNetworkClient(
      MockClient((_) async => throw http.ClientException('refused')),
      baseUrl: 'https://api.example.test/v1',
    );
    await expectLater(
      client.send(_get),
      throwsA(isA<NetworkException>().having((e) => e.code, 'code', 'CONNECTION_ERROR')),
    );
  });

  test('a 200 returns a NetworkResponse with decoded JSON, base URL and query applied', () async {
    late Uri seen;
    final client = HttpNetworkClient(
      MockClient((req) async {
        seen = req.url;
        return http.Response('{"id":1}', 200, headers: {'x-a': 'b'});
      }),
      baseUrl: 'https://api.example.test/v1',
    );
    final response = await client.send(const NetworkRequest(
      path: '/items',
      method: NetworkMethod.get,
      queryParameters: {'page': 2},
    ));
    expect(seen.toString(), 'https://api.example.test/v1/items?page=2');
    expect(response.statusCode, 200);
    expect(response.data, {'id': 1});
    expect(response.headers['x-a'], ['b']);
  });
}
