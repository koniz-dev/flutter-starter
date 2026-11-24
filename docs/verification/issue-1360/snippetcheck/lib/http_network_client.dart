// lib/core/network/adapters/http_network_client.dart
import 'dart:convert';

import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:http/http.dart' as http;

class HttpNetworkClient implements INetworkClient {
  HttpNetworkClient(this._client, {required this.baseUrl});

  final http.Client _client;
  final String baseUrl;

  @override
  Future<NetworkResponse<dynamic>> send(NetworkRequest request) async {
    final uri = Uri.parse('$baseUrl${request.path}').replace(
      queryParameters: request.queryParameters.isEmpty
          ? null
          : request.queryParameters.map((k, v) => MapEntry(k, '$v')),
    );
    final httpRequest =
        http.Request(request.method.name.toUpperCase(), uri)
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            ...request.headers,
          });
    if (request.body != null) httpRequest.body = jsonEncode(request.body);

    final http.Response response;
    try {
      final streamed = await _client.send(httpRequest);
      response = await http.Response.fromStream(streamed);
    } on http.ClientException catch (e) {
      // Only the transport failure is caught here.
      throw NetworkException(
        'Connection error: ${e.message}',
        code: 'CONNECTION_ERROR',
      );
    }

    // Outside the try, so a 4xx/5xx is not re-labelled a network error.
    if (response.statusCode >= 400) {
      throw ServerException(
        'Server error',
        statusCode: response.statusCode,
      );
    }
    return NetworkResponse<dynamic>(
      statusCode: response.statusCode,
      data: response.body.isEmpty ? null : jsonDecode(response.body),
      headers: response.headers.map((k, v) => MapEntry(k, [v])),
    );
  }
}
