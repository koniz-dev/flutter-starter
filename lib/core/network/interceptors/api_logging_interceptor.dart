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
      'path': redactPath(options.path),
      'baseUrl': options.baseUrl,
      'headers': _sanitizeHeaders(options.headers),
      if (options.queryParameters.isNotEmpty)
        'queryParameters': _sanitizeMap(
          options.queryParameters,
          isSensitive: isSensitiveQueryKey,
        ),
      if (options.data != null) 'body': _sanitizeBody(options.data),
    };

    _loggingService.debug(
      'API Request: ${options.method} ${redactPath(options.path)}',
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
      'path': redactPath(response.requestOptions.path),
      'headers': _sanitizeHeaders(response.headers.map),
      if (response.data != null) 'body': _sanitizeBody(response.data),
    };

    // Log as warning for error status codes, info for success
    if (response.statusCode! >= 400) {
      _loggingService.warning(
        'API Response: ${response.statusCode} '
        '${redactPath(response.requestOptions.path)}',
        context: context,
      );
    } else {
      _loggingService.info(
        'API Response: ${response.statusCode} '
        '${redactPath(response.requestOptions.path)}',
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
      'path': redactPath(err.requestOptions.path),
      'method': err.requestOptions.method,
      'statusCode': err.response?.statusCode,
      if (err.response?.data != null)
        'responseBody': _sanitizeBody(err.response!.data),
      if (err.requestOptions.data != null)
        'requestBody': _sanitizeBody(err.requestOptions.data),
    };

    _loggingService.error(
      'API Error: ${err.type} ${redactPath(err.requestOptions.path)}',
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
  /// redact an unrelated header by accident. [isSensitiveKey] is applied as a
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
    // Strapi returns its session token as `jwt`.
    'jwt',
    // AWS-style `access_key`, Firebase/Baidu-style `app_key`, `client_key`.
    'accesskey',
    'appkey',
    'clientkey',
    // A request HMAC (`hmac=`, `x-hmac-sha256`).
    'hmac',
    // Azure APIM `subscription-key` / `Ocp-Apim-Subscription-Key`, Azure
    // Functions `x-functions-key`, and `session_key`, `auth_key`,
    // `master_key`, `license_key`. No ordinary field name contains these.
    'subscriptionkey',
    'functionskey',
    'sessionkey',
    'authkey',
    'masterkey',
    'licensekey',
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
    // Azure Storage SAS signature (`?sv=...&sig=...`): `signal` must stay.
    'sig',
    // Firebase Realtime Database REST ID token (`?auth=...`): `author`
    // and `oauthprovider` must stay.
    'auth',
    // A raw bearer token passed as a parameter.
    'bearer',
    // Alibaba- and CDN-style signed URLs (`?sign=...`): `signal` and `signup`
    // must stay.
    'sign',
    // The Google APIs key (`?key=AIza...`): `monkey` and `keyword` must stay.
    'key',
    // Django REST Framework SimpleJWT's token fields: `accessLevel` and
    // `refreshInterval` must stay.
    'access',
    'refresh',
  };

  /// Keys that name a secret in a query string only, matched exactly.
  ///
  /// `code` is an OAuth authorization code or an Azure Functions key in a
  /// query (`?code=...`), but the error or status code in most response
  /// bodies (`{"code": 404}`), where redacting it would blind every error log.
  static const _sensitiveQueryOnlyKeys = <String>{'code'};

  /// A `%` not followed by two hex digits: an escape that names no byte.
  static final RegExp _malformedPercent = RegExp('%(?![0-9A-Fa-f]{2})');

  /// [rawKey] decoded the way a query component is, without ever throwing,
  /// or `null` when it holds a `%` that names no byte.
  ///
  /// `Uri.decodeQueryComponent` throws not only on a bare `%` but on escapes
  /// that are well formed yet not UTF-8 (`%E9`, `%FF` - Latin-1 keys from
  /// legacy backends) and on raw non-ASCII (`café`). `PerformanceInterceptor`
  /// redacts every request's path, so any of those failed the request itself,
  /// in every build. Invalid bytes decode to U+FFFD instead, which the key
  /// rules then ignore like any other separator.
  static String? _decodeKey(String rawKey) {
    if (_malformedPercent.hasMatch(rawKey)) return null;
    final runes = rawKey.runes.toList();
    final bytes = <int>[];
    for (var i = 0; i < runes.length; i++) {
      final rune = runes[i];
      if (rune == 0x25) {
        final hex = String.fromCharCodes(runes.sublist(i + 1, i + 3));
        bytes.add(int.parse(hex, radix: 16));
        i += 2;
      } else if (rune == 0x2B) {
        bytes.add(0x20);
      } else {
        bytes.addAll(utf8.encode(String.fromCharCode(rune)));
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// A backslash, spelled by code unit: `r'\'` reads to the docs tooling's
  /// declaration scanner as an escaped quote that never closes.
  static final String _backslash = String.fromCharCode(0x5C);

  /// Where an authority begins, as `Uri.parse` and dart:io see it: after an
  /// optional `scheme:`, two characters that are each `/` or `\`. So
  /// `ws:\\user:pass@host` and `//user:pass@host` have userinfo too - and
  /// the first one is sent to the server as credentials.
  static final RegExp _authorityStart = RegExp(
    r'^(?:[A-Za-z][A-Za-z0-9+.\-]*:)?[/\\]{2}',
  );

  /// [url] fit for a log line or an error message: its userinfo replaced,
  /// then every query value whose key names a secret, as [redactPath] does.
  ///
  /// Userinfo is cut out of the raw text - everything between the start of
  /// the authority and its last `@` - not found through `Uri`, which
  /// normalises it (`%2f` to `%2F`, `%41` to `A`) and so misses the original,
  /// and which cannot parse a malformed URL at all.
  static String redactUrl(String url) {
    var text = url;
    final authority = _authorityStart.firstMatch(text);
    if (authority != null) {
      final authorityStart = authority.end;
      var authorityEnd = text.length;
      for (final delimiter in ['/', _backslash, '?', '#']) {
        final index = text.indexOf(delimiter, authorityStart);
        if (index >= 0 && index < authorityEnd) authorityEnd = index;
      }
      final at = authorityEnd > authorityStart
          ? text.lastIndexOf('@', authorityEnd - 1)
          : -1;
      if (at >= authorityStart) {
        text =
            '${text.substring(0, authorityStart)}$_redacted'
            '${text.substring(at)}';
      }
    }
    return redactPath(text);
  }

  /// [path] with every query parameter embedded in it that names a secret
  /// redacted, by the same key rules as `queryParameters`.
  ///
  /// `ApiClient` takes a path, so `get('/verify?token=X')` is a normal call,
  /// and that path used to be logged verbatim in the request, response and
  /// error entries. Everything except the
  /// redacted values is kept exactly as written.
  static String redactPath(String path) {
    final queryStart = path.indexOf('?');
    if (queryStart < 0) return path;
    final fragmentStart = path.indexOf('#', queryStart);
    final queryEnd = fragmentStart < 0 ? path.length : fragmentStart;
    final query = path.substring(queryStart + 1, queryEnd).split('&').map((
      pair,
    ) {
      final equals = pair.indexOf('=');
      if (equals < 0) return pair;
      final rawKey = pair.substring(0, equals);
      final key = _decodeKey(rawKey);
      // A key that cannot be read cannot be cleared either: its value is
      // redacted.
      if (key == null) return '$rawKey=$_redacted';
      return isSensitiveQueryKey(key) ? '$rawKey=$_redacted' : pair;
    });
    return '${path.substring(0, queryStart + 1)}${query.join('&')}'
        '${path.substring(queryEnd)}';
  }

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
  ///
  /// Public because `CacheInterceptor` uses the same rule to keep a request
  /// whose query carries a secret out of its plaintext store: one list, so
  /// the two cannot drift.
  static bool isSensitiveKey(String key) {
    final normalized = _normalizeKey(key);
    if (_sensitiveKeysExact.contains(normalized)) return true;
    return _sensitiveKeyFragments.any(normalized.contains);
  }

  /// Whether a query parameter key names a secret: [isSensitiveKey], plus
  /// the names that are secrets only in a query string (`code`).
  ///
  /// Used for every query - [redactPath], [redactUrl], the logged
  /// `queryParameters` - and for `CacheInterceptor`'s secret-query bypass.
  static bool isSensitiveQueryKey(String key) =>
      isSensitiveKey(key) ||
      _sensitiveQueryOnlyKeys.contains(_normalizeKey(key));

  /// Sanitize headers to remove sensitive information
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};

    for (final entry in headers.entries) {
      final key = entry.key.trim();
      sanitized[entry.key] =
          _sensitiveHeaderKeys.contains(key.toLowerCase()) ||
              isSensitiveKey(key)
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
      // Reached through a key that [isSensitiveKey] already cleared.
      return value;
    }
    if (value is Map) return _sanitizeMap(value);
    if (value is List) return value.map<dynamic>(_sanitizeValue).toList();

    // FormData, streams, byte buffers, arbitrary objects: not walkable, and a
    // multipart login form is a real credential carrier.
    return _redacted;
  }

  /// Sanitize a map of keyed values - a JSON object or a query parameter map.
  ///
  /// [isSensitive] judges the top-level keys: [isSensitiveQueryKey] for a
  /// query parameter map. Nested maps use [isSensitiveKey].
  Map<String, dynamic> _sanitizeMap(
    Map<dynamic, dynamic> map, {
    bool Function(String key) isSensitive = isSensitiveKey,
  }) {
    final sanitized = <String, dynamic>{};

    for (final entry in map.entries) {
      final key = entry.key.toString();
      sanitized[key] = isSensitive(key)
          ? _redacted
          : _sanitizeValue(entry.value);
    }

    return sanitized;
  }
}
