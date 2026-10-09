// Lightweight boundary contract file; repetitive per-member docs are omitted.
// ignore_for_file: public_member_api_docs, one_member_abstracts

/// Supported HTTP methods for transport-agnostic requests.
enum NetworkMethod { get, post, put, patch, delete }

/// Generic network request contract.
class NetworkRequest {
  const NetworkRequest({
    required this.path,
    required this.method,
    this.body,
    this.headers = const <String, String>{},
    this.queryParameters = const <String, dynamic>{},
    this.timeout,
  });

  final String path;
  final NetworkMethod method;
  final dynamic body;
  final Map<String, String> headers;
  final Map<String, dynamic> queryParameters;
  final Duration? timeout;
}

/// Generic network response contract.
class NetworkResponse<T> {
  const NetworkResponse({
    required this.statusCode,
    required this.data,
    this.headers = const <String, List<String>>{},
  });

  final int statusCode;
  final T data;
  final Map<String, List<String>> headers;
}

/// Normalized network error contract at the transport boundary.
class NetworkError implements Exception {
  const NetworkError({
    required this.message,
    this.code,
    this.statusCode,
    this.cause,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;

  /// Carries the message, code and status, so wrapping this in another
  /// exception never degrades to `Instance of 'NetworkError'`
  /// (koniz-dev/flutter-starter#276).
  @override
  String toString() {
    final details = <String>[
      if (code != null) 'code: $code',
      if (statusCode != null) 'statusCode: $statusCode',
    ];
    final label = details.isEmpty
        ? 'NetworkError'
        : 'NetworkError(${details.join(', ')})';
    return '$label: $message';
  }
}

/// Transport-agnostic network client contract.
abstract class INetworkClient {
  Future<NetworkResponse<dynamic>> send(NetworkRequest request);
}

/// Locally persisted HTTP response cache, as seen from outside the transport.
///
/// Exists so session teardown can drop cached response bodies without the auth
/// layer importing `ApiClient` or any dio type.
abstract class IHttpResponseCache {
  Future<void> clearCache();
}
