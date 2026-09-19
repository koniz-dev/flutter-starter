import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';

/// Enhanced interceptor for logging HTTP requests and responses
///
/// This interceptor provides comprehensive logging for API calls including:
/// - Request method, path, headers, query parameters, and body
/// - Response status code, headers, and body
/// - Error details with stack traces
///
/// The interceptor respects the ENABLE_HTTP_LOGGING flag from AppConfig.
class ApiLoggingInterceptor extends Interceptor {
  /// Creates an [ApiLoggingInterceptor] with the given [loggingService]
  ApiLoggingInterceptor({required LoggingService loggingService})
    : _loggingService = loggingService;

  /// Logging service instance
  final LoggingService _loggingService;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!AppConfig.enableHttpLogging) {
      super.onRequest(options, handler);
      return;
    }

    final context = <String, dynamic>{
      'method': options.method,
      'path': options.path,
      'baseUrl': options.baseUrl,
      'headers': _sanitizeHeaders(options.headers),
      if (options.queryParameters.isNotEmpty)
        'queryParameters': _sanitizeMap(options.queryParameters),
      if (options.data != null) 'body': _sanitizeBody(options.data),
    };

    _loggingService.debug(
      'API Request: ${options.method} ${options.path}',
      context: context,
    );

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (!AppConfig.enableHttpLogging) {
      super.onResponse(response, handler);
      return;
    }

    final context = <String, dynamic>{
      'statusCode': response.statusCode,
      'path': response.requestOptions.path,
      'headers': _sanitizeHeaders(response.headers.map),
      if (response.data != null) 'body': _sanitizeBody(response.data),
    };

    // Log as warning for error status codes, info for success
    if (response.statusCode! >= 400) {
      _loggingService.warning(
        'API Response: ${response.statusCode} ${response.requestOptions.path}',
        context: context,
      );
    } else {
      _loggingService.info(
        'API Response: ${response.statusCode} ${response.requestOptions.path}',
        context: context,
      );
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!AppConfig.enableHttpLogging) {
      super.onError(err, handler);
      return;
    }

    final context = <String, dynamic>{
      'type': err.type.toString(),
      'path': err.requestOptions.path,
      'method': err.requestOptions.method,
      'statusCode': err.response?.statusCode,
      if (err.response?.data != null)
        'responseBody': _sanitizeBody(err.response!.data),
      if (err.requestOptions.data != null)
        'requestBody': _sanitizeBody(err.requestOptions.data),
    };

    _loggingService.error(
      'API Error: ${err.type} ${err.requestOptions.path}',
      context: context,
      error: err,
      stackTrace: err.stackTrace,
    );

    super.onError(err, handler);
  }

  /// The single placeholder written in place of any redacted value.
  static const _redacted = '***REDACTED***';

  /// Header names whose values must never reach a log sink, lowercased.
  ///
  /// Matched case-insensitively. Dio keeps headers in a case-insensitive map
  /// that stores each key exactly as the caller wrote it, so `AuthInterceptor`
  /// (`options.headers['Authorization'] = ...`) hands this interceptor a
  /// capitalised key. A case-sensitive lookup against these literals would
  /// miss it and log the bearer token verbatim.
  ///
  /// This is an exact-match list on purpose: header names are a closed,
  /// standardised namespace, so an explicit roster is auditable and cannot
  /// redact an unrelated header by accident. [_isSensitiveKey] is applied as a
  /// second pass so a non-standard credential header still gets caught.
  static const _sensitiveHeaderKeys = <String>{
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'api-key',
    'x-auth-token',
    'x-refresh-token',
    'x-csrf-token',
  };

  /// Key fragments: a normalised key that *contains* one of these is redacted.
  ///
  /// Normalisation lowercases and drops every non-alphanumeric character, so
  /// `access_token`, `accessToken` and `X-Access-Token` all reduce to
  /// `accesstoken` and match the `token` fragment.
  static const _sensitiveKeyFragments = <String>{
    'password',
    'passwd',
    'passphrase',
    'token',
    'secret',
    'apikey',
    'credential',
    'authorization',
    'privatekey',
    'creditcard',
    'cardnumber',
    'signature',
    'pincode',
    'otpcode',
  };

  /// Keys that must match the normalised key *exactly*.
  ///
  /// These are too short to use as fragments: `pin` occurs inside `shipping`,
  /// `cvc` inside `cvcNote`. Matching them exactly keeps innocent fields
  /// readable while still redacting the real credential field.
  static const _sensitiveKeysExact = <String>{
    'pin',
    'otp',
    'cvv',
    'cvc',
    'session',
    'sessionid',
  };

  /// Reduce a key to a comparable form: lowercase, alphanumerics only.
  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// Whether a map key (body field, query parameter or header name) names a
  /// secret.
  ///
  /// Redaction is decided by **key name only** - never by the shape of the
  /// value. Shape matching (say, "anything that looks like a JWT") would catch
  /// tokens hiding under unexpected key names, but it also redacts legitimate
  /// base64 payloads, hashes and opaque ids, and it makes the redaction set
  /// impossible to predict by reading the code. The cost of the key-name rule
  /// is stated plainly in `docs/api/core/network.md`: a secret carried under a
  /// key name that is not listed here is still logged, so these lists are the
  /// security boundary and must grow when an API invents a new credential
  /// parameter.
  static bool _isSensitiveKey(String key) {
    final normalized = _normalizeKey(key);
    if (_sensitiveKeysExact.contains(normalized)) return true;
    return _sensitiveKeyFragments.any(normalized.contains);
  }

  /// Sanitize headers to remove sensitive information
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};

    for (final entry in headers.entries) {
      final key = entry.key.trim();
      sanitized[entry.key] =
          _sensitiveHeaderKeys.contains(key.toLowerCase()) ||
              _isSensitiveKey(key)
          ? _redacted
          : entry.value;
    }

    return sanitized;
  }

  /// Sanitize a request/response body before it reaches a log sink.
  ///
  /// The rule is an allow-list. Only shapes this interceptor can actually walk
  /// are logged; anything else is replaced wholesale, because a value it cannot
  /// walk is a value whose secrets it cannot find.
  dynamic _sanitizeBody(dynamic body) {
    if (body == null) return null;
    if (body is String) return _sanitizeStringBody(body);
    return _sanitizeValue(body);
  }

  /// Sanitize a `String` body.
  ///
  /// A pre-encoded JSON object or array - what `dio.post(path,
  /// data: jsonEncode(...))` produces - is decoded and sanitized field by
  /// field. Anything else is redacted **wholesale**: a form-encoded body
  /// (`grant_type=password&password=hunter2`), a plain-text error page or a
  /// bare JSON scalar offers no keys to judge, and logging it verbatim because
  /// parsing failed is exactly the bug this replaces. The trade-off is the loss
  /// of plain-text diagnostics; the status code, path and method are still
  /// logged alongside.
  dynamic _sanitizeStringBody(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return _redacted;
    }

    if (decoded is Map || decoded is List) return _sanitizeValue(decoded);

    // A bare JSON scalar ('"<refresh-token>"') carries no key to judge by.
    return _redacted;
  }

  /// Recursively sanitize a decoded value.
  dynamic _sanitizeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      // Reached through a key that [_isSensitiveKey] already cleared.
      return value;
    }
    if (value is Map) return _sanitizeMap(value);
    if (value is List) return value.map<dynamic>(_sanitizeValue).toList();

    // FormData, streams, byte buffers, arbitrary objects: not walkable, and a
    // multipart login form is a real credential carrier.
    return _redacted;
  }

  /// Sanitize a map of keyed values - a JSON object or a query parameter map.
  Map<String, dynamic> _sanitizeMap(Map<dynamic, dynamic> map) {
    final sanitized = <String, dynamic>{};

    for (final entry in map.entries) {
      final key = entry.key.toString();
      sanitized[key] = _isSensitiveKey(key)
          ? _redacted
          : _sanitizeValue(entry.value);
    }

    return sanitized;
  }
}
