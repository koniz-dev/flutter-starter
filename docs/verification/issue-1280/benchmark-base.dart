import 'dart:convert';
class ApiLoggingInterceptor {
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

  /// The version of the key rules below ([_sensitiveKeyFragments],
  /// [_sensitiveKeysExact], [_sensitiveQueryOnlyKeys], [_sensitiveHeaderKeys]).
  ///
  /// `CacheInterceptor` stores it, and drops every cached response when it
  /// changes: a response cached before a key joined the rules was cached for
  /// a URL that now names a secret, and is never read or evicted again.
  /// Version 3 also rejects sensitive request headers and header-dependent
  /// Vary responses from the URL-only cache. Bump it when cache admission
  /// becomes stricter or any of these sets changes;
  /// `cache_rule_version_test.dart` fails until you do.
  static const int sensitiveKeyRuleVersion = 3;

  /// The key rules as one comparable string, for the version test.
  static String get debugKeyRuleFingerprint => [
    (_sensitiveKeyFragments.toList()..sort()).join(','),
    (_sensitiveKeysExact.toList()..sort()).join(','),
    (_sensitiveQueryOnlyKeys.toList()..sort()).join(','),
    (_sensitiveHeaderKeys.toList()..sort()).join(','),
  ].join('|');

  /// Keys that name a secret in URL parameters only, matched exactly.
  ///
  /// `code` is an OAuth authorization code or an Azure Functions key in a
  /// query (`?code=...`), but the error or status code in most response
  /// bodies (`{"code": 404}`), where redacting it would blind every error log.
  /// `ticket` authenticates WebSocket URLs but may be ordinary body data.
  static const _sensitiveQueryOnlyKeys = <String>{'code', 'ticket'};

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
  /// then every query/fragment value whose key names a secret, as
  /// [redactPath] does.
  ///
  /// Userinfo is cut out of the raw text - everything between the start of
  /// the authority and its last `@` - not found through `Uri`, which
  /// normalises it (`%2f` to `%2F`, `%41` to `A`) and so misses the original,
  /// and which cannot parse a malformed URL at all.
  static String redactUrl(String url) {
    // Leading whitespace kept the authority pattern, anchored at the start,
    // from matching, and the userinfo went out unredacted; such a URL is
    // invalid anyway, so it is logged trimmed.
    var text = url.trimLeft();
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

  /// [path] with sensitive query and fragment parameters redacted.
  ///
  /// Includes OAuth fragments (`#access_token=...`) and router fragments
  /// (`#/callback?code=...`). Other text and parameter spelling are preserved.
  static String redactPath(String path) {
    final fragmentStart = path.indexOf('#');
    final base = fragmentStart < 0 ? path : path.substring(0, fragmentStart);
    final queryStart = base.indexOf('?');
    final safeBase = queryStart < 0
        ? base
        : '${base.substring(0, queryStart + 1)}'
              '${_redactParameters(base.substring(queryStart + 1))}';
    if (fragmentStart < 0) return safeBase;

    final fragment = path.substring(fragmentStart + 1);
    final routeQuery = fragment.indexOf('?');
    final equals = fragment.indexOf('=');
    // Only explicit path/hashbang fragments have a router prefix. A ? in a
    // parameter key or value must not exempt any credential from redaction.
    final isRoute = fragment.startsWith('/') || fragment.startsWith('!/');
    final prefixLength =
        isRoute && routeQuery >= 0 && (equals < 0 || routeQuery < equals)
        ? routeQuery + 1
        : 0;
    return '$safeBase#${fragment.substring(0, prefixLength)}'
        '${_redactParameters(fragment.substring(prefixLength))}';
  }

  static String _redactParameters(String parameters) => parameters
      .split('&')
      .map((pair) {
        final equals = pair.indexOf('=');
        if (equals < 0) return pair;
        final rawKey = pair.substring(0, equals);
        final key = _decodeKey(rawKey);
        // A key that cannot be read cannot be cleared either.
        if (key == null || isSensitiveQueryKey(key)) {
          return '$rawKey=$_redacted';
        }
        return pair;
      })
      .join('&');

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
  /// the names that are secrets only in URL parameters (`code`, `ticket`).
  ///
  /// Used for every query - [redactPath], [redactUrl], the logged
  /// `queryParameters` - and for `CacheInterceptor`'s secret-query bypass.
  static bool isSensitiveQueryKey(String key) =>
      isSensitiveKey(key) ||
      _sensitiveQueryOnlyKeys.contains(_normalizeKey(key));

  /// Whether a header names credentials; shared with plaintext cache bypass.
  static bool isSensitiveHeaderKey(String key) =>
      _sensitiveHeaderKeys.contains(key.trim().toLowerCase()) ||
      isSensitiveKey(key);

}
void main() {
  for (final n in [1000, 2000, 4000, 8000, 16000, 32000]) {
    final path = '/cb#section${'?view=a' * n}';
    final sw = Stopwatch()..start();
    final out = ApiLoggingInterceptor.redactUrl(path);
    sw.stop();
    print('N=$n chars=${path.length} us=${sw.elapsedMicroseconds} unchanged=${out==path}');
  }
}
