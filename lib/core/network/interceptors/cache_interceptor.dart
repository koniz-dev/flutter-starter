import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/date_formatter.dart';
import 'package:flutter_starter/core/utils/json_helper.dart';

/// Cache configuration for HTTP responses
class CacheConfig {
  /// Creates a [CacheConfig] with the given parameters
  const CacheConfig({
    this.maxAge = const Duration(hours: 1),
    this.maxStale = const Duration(days: 7),
    this.enableCache = true,
  });

  /// How long a cached response is served without asking the network.
  ///
  /// Past this age the request goes to the network; the cached response is
  /// only a fallback for when that fetch fails (see [maxStale]).
  final Duration maxAge;

  /// How long a cached response may still stand in for a failed fetch.
  ///
  /// Between [maxAge] and this age, an entry is served only if the network
  /// request fails for transport reasons - a connection error, a timeout, or
  /// a 5xx. Past it the entry is evicted.
  final Duration maxStale;

  /// Whether caching is enabled
  final bool enableCache;
}

/// Interceptor for caching HTTP responses.
///
/// ## Freshness
///
/// An entry younger than [CacheConfig.maxAge] is served without a network
/// request. An older one - up to [CacheConfig.maxStale] - is stale: the
/// request goes to the network, and the stale entry is served only if that
/// fetch fails for transport reasons (connection error, timeout or 5xx). A
/// 4xx is the server's answer and is passed through. A successful refetch
/// replaces the entry. `maxAge` used to have no effect: a stale entry was
/// served straight from the cache for up to seven days with no network
/// attempt at all.
/// ## What is cached
///
/// Only **unauthenticated** `GET` responses with status 200, for a request
/// whose query carries no key that [ApiLoggingInterceptor.isSensitiveQueryKey]
/// treats as a secret, and whose headers contain no key matched by
/// [ApiLoggingInterceptor.isSensitiveHeaderKey]. Before touching
/// the cache - on read and on write - the interceptor asks the [ITokenStore]
/// whether a session credential exists. If one does, the request neither
/// reads from nor writes to the cache and goes straight to the network.
///
/// The credential check deliberately reads the token store rather than
/// sniffing `options.headers` for `Authorization`. `AuthInterceptor` writes
/// that header from its own `onRequest`, and dio runs `onRequest` in
/// registration order, so a header sniff only works while this interceptor
/// happens to be registered *after* `AuthInterceptor` - an invariant nothing
/// enforces, on a surface that has already proved easy to get wrong. Reading
/// the same store `AuthInterceptor` reads makes the
/// decision correct at any position in the chain. The header check is kept as
/// a secondary guard for credentials a caller attaches by hand through
/// `Options(headers: ...)`, which *are* already present this early.
///
/// ## What the server can refuse
///
/// A response whose `Cache-Control` names `no-store`, `private` or
/// `no-cache` (or that carries `Pragma: no-cache`), or that sets a cookie, is
/// passed through and never written, and any entry already stored for that
/// URL is removed. `no-store` and `private` are the server saying the body is
/// not for a shared or persistent cache - an anonymous email-verification or
/// password-reset check, a presigned download - and the store below is both.
/// `no-cache` allows storing only if every reuse is revalidated, and this
/// cache serves a fresh entry without asking the network, so it does not
/// store one at all.
/// A `Vary` field naming any other request header also prevents storage: the
/// URL-only key covers no request headers, so it cannot distinguish the
/// requested variants. `Accept-Encoding` and `Origin` are the exceptions:
/// the HTTP stack negotiates the encoding and hands over the decoded body,
/// and an app's origin never changes, so neither selects a different body
/// here. Servers behind gzip or a CDN send `Vary: Accept-Encoding` on every
/// response, and refusing it disabled the cache against real APIs.
///
/// On web, a cross-origin response exposes `Vary` to script only when the
/// server lists it in `Access-Control-Expose-Headers`; otherwise the rule
/// above sees no `Vary` and stores the response. Mark responses that differ
/// per request header `Cache-Control: private` on the server instead.
///
/// The `Set-Cookie` rule has **no effect on Flutter web**. Browsers never
/// expose `Set-Cookie` to script (the Fetch spec lists it as a forbidden
/// response header), and dio's web adapter reads headers through
/// `getAllResponseHeaders()`, so a cookie-setting response looks cookie-free
/// here. On web, mark such responses `Cache-Control: private` or `no-store`
/// on the server; those headers are visible and honoured.
///
/// ## Where it is stored
///
/// In [StorageService], i.e. `shared_preferences` - plaintext, readable on a
/// rooted or jailbroken device and included in unencrypted device backups.
/// Requests identified by the shared credential rule never land there. Custom
/// credential names must match that rule or explicitly bypass caching. Do not
/// relax the credential check without moving to encrypted storage.
///
/// Keys are a SHA-256 of the request URL ([cacheKeyFor]), never the URL
/// itself, so a token in a query string is not written to disk as part of a
/// key or of the key index. Entries written under the old verbatim-URL keys
/// and listed in the index are removed the first time a request passes
/// through, with caching enabled or not.
///
/// ## How an entry is aged
///
/// Each body is stored beside a timestamp written with
/// [DateFormatter.formatIso8601], so it is always UTC and always carries the
/// `Z` designator, and read back with [DateFormatter.parseIso8601]. Age is
/// then the difference between two absolute instants, which is what
/// `maxAge`/`maxStale` are comparing against.
///
/// The wall-clock pair ([DateFormatter.formatDateTime] /
/// [DateFormatter.parseDateTime]) must not be used here: it writes no
/// timezone marker, so the reader has to assume its own current offset. That
/// is exactly a defect this cache once had - a bare
/// `DateTime.now().toIso8601String()` on a local `DateTime` emits neither `Z`
/// nor an offset, so after a flight or a DST transition every entry written
/// before the change was aged out by the offset, evicting fresh entries in
/// one direction and serving stale ones past `maxStale` in the other.
///
/// Two kinds of already-stored string survive the change:
///
/// - **Offset-less legacy entries** keep being read as local wall clock,
///   which is what `DateTime.parse` did for them before, so no entry on disk
///   jumps at upgrade time. They are as wrong as they always were and no
///   more, and they drain on their own: the first refetch after `maxAge`
///   rewrites the timestamp in the new form. No migration ships, for the
///   simple reason that the offset in force at write time was never
///   recorded, so a migration would have to assume the device's current
///   offset, which is the same assumption the read path already makes at the
///   same moment.
/// - **Unparseable or out-of-range strings** are discarded rather than
///   guessed at. `DateTime.parse` rolls `2024-02-30` over to 1 March and so
///   answers a plausible-looking age for a corrupt entry;
///   [DateFormatter.parseIso8601] returns null instead, and the entry is
///   removed and reported as a miss. A cache entry is disposable by
///   construction, so the whole cost of being wrong here is one network
///   request.
///
/// ## Lifetime
///
/// [clearCache] removes every entry. It is wired to logout through
/// [IHttpResponseCache], so an anonymous response cached before sign-in
/// cannot outlive the session boundary.
class CacheInterceptor extends Interceptor implements IHttpResponseCache {
  /// Creates a [CacheInterceptor] with the given [storageService],
  /// [cacheConfig] and [tokenStore].
  ///
  /// [tokenStore] should be the same store `AuthInterceptor` uses. When it is
  /// omitted the interceptor cannot tell an authenticated request from an
  /// anonymous one and falls back to the header check alone, so production
  /// wiring must always supply it - `ApiClient` does.
  CacheInterceptor({
    required StorageService storageService,
    CacheConfig? cacheConfig,
    ITokenStore? tokenStore,
  }) : _storageService = storageService,
       _tokenStore = tokenStore,
       _cacheConfig = cacheConfig ?? const CacheConfig();

  final StorageService _storageService;
  final CacheConfig _cacheConfig;
  final ITokenStore? _tokenStore;

  /// Cache key prefix
  static const String _cacheKeyPrefix = 'http_cache_';

  /// Timestamp key prefix
  static const String _timestampKeyPrefix = 'http_cache_timestamp_';

  /// Key holding the list of every cache key currently written.
  ///
  /// `StorageService` exposes no key enumeration, so the interceptor keeps its
  /// own index. Without it [clearCache] cannot know what to remove - which is
  /// why the previous implementation was an empty method body.
  static const String _indexKey = 'http_cache_index';

  /// HTTP methods that should be cached
  static const List<String> _cacheableMethods = ['GET'];

  /// A key written by [cacheKeyFor]; anything else under [_cacheKeyPrefix] in
  /// the index is a verbatim-URL key from before keys were hashed.
  static final RegExp _hashedKey = RegExp(r'^http_cache_[0-9a-f]{64}$');

  /// The one-off removal of verbatim-URL entries and of entries cached under
  /// an older key rule; see [_purgeLegacyEntries].
  Future<bool>? _legacyPurge;

  /// The [ApiLoggingInterceptor.sensitiveKeyRuleVersion] the stored entries
  /// were cached under, written with the first entry and removed by
  /// [clearCache]. Outside the `http_cache_` prefix: it is bookkeeping, not a
  /// cached response.
  static const String _ruleVersionKey = 'cache_rule_version';

  /// `RequestOptions.extra` key carrying a stale entry while its refetch is
  /// in flight; see [onError].
  static const String _staleFallbackKey = 'http_cache_stale_fallback';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // First, and whether or not caching is on: entries an earlier version
    // stored under a verbatim URL can hold a query-string secret, and with
    // caching disabled nothing else would ever touch them again.
    if (!await _purgeLegacyEntries()) {
      return super.onRequest(options, handler);
    }

    // Only cache GET requests
    if (!_cacheConfig.enableCache ||
        !_cacheableMethods.contains(options.method.toUpperCase())) {
      return super.onRequest(options, handler);
    }

    // Check if request should bypass cache
    if (await _shouldBypassCache(options)) {
      return super.onRequest(options, handler);
    }

    // Try to get cached response
    final cacheKey = cacheKeyFor(options);
    final cachedData = await _getCachedResponse(cacheKey);

    if (cachedData != null) {
      final headers = cachedData['headers'] as Map<String, List<String>>?;
      final cachedResponse = Response<dynamic>(
        data: cachedData['data'],
        statusCode: 200,
        requestOptions: options,
        headers: Headers.fromMap(headers ?? <String, List<String>>{}),
      );

      // Fresh: answer from the cache. Stale: refetch, keeping the entry as
      // the fallback onError serves if the network fails.
      if (cachedData['stale'] != true) {
        return handler.resolve(cachedResponse);
      }
      options.extra[_staleFallbackKey] = cachedResponse;
    }

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final stale = err.requestOptions.extra.remove(_staleFallbackKey);
    if (stale is Response<dynamic> && _isTransportFailure(err)) {
      return handler.resolve(stale);
    }
    super.onError(err, handler);
  }

  /// Whether [err] means the network could not answer, as opposed to the
  /// server answering with an error of its own.
  static bool _isTransportFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        return (err.response?.statusCode ?? 0) >= 500;
      // The network did answer; the body then took too long to decode on
      // this device. Serving the stale copy would hide that, so it surfaces.
      case DioExceptionType.transformTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final requestOptions = response.requestOptions;

    // Only cache successful GET responses
    if (!_cacheConfig.enableCache ||
        !_cacheableMethods.contains(requestOptions.method.toUpperCase()) ||
        response.statusCode != 200) {
      return super.onResponse(response, handler);
    }

    if (!await _purgeLegacyEntries()) {
      return super.onResponse(response, handler);
    }

    // The server refused storage: drop whatever an earlier response left
    // under this URL too, or it would keep being served, fresh and then as a
    // stale fallback.
    if (_responseForbidsStorage(response)) {
      final cacheKey = cacheKeyFor(requestOptions);
      await _evictEntry(cacheKey, '$_timestampKeyPrefix$cacheKey');
      return super.onResponse(response, handler);
    }

    // Check if response should be cached
    if (await _shouldBypassCache(requestOptions)) {
      return super.onResponse(response, handler);
    }

    // Cache the response
    final cacheKey = cacheKeyFor(requestOptions);
    await _cacheResponse(cacheKey, response.data, response.headers.map);

    super.onResponse(response, handler);
  }

  /// Checks if the request should bypass cache
  Future<bool> _shouldBypassCache(RequestOptions options) async {
    // Check for no-cache header
    final cacheControl = options.headers['cache-control'] as String?;
    if (cacheControl != null &&
        (cacheControl.toLowerCase().contains('no-cache') ||
            cacheControl.toLowerCase().contains('no-store'))) {
      return true;
    }

    // A secret in the query - a verification or reset token, a presigned
    // URL's signature - means the response is about that secret, and the
    // store is plaintext. The log redaction's own rule, applied to the whole
    // URL, so the two cannot drift: anything it would redact (a nested
    // `?redirect=...?token=`, a `;token=`, userinfo) bypasses the cache. A
    // query that does not parse is treated the same way.
    if (_querySecret(options)) return true;

    // Secondary guard: a credential the caller attached directly to the
    // request is visible here regardless of interceptor order.
    if (options.headers.keys.any(ApiLoggingInterceptor.isSensitiveHeaderKey)) {
      return true;
    }

    // Primary guard: never touch the cache while a session credential exists.
    return await _hasSessionCredential();
  }

  /// Whether [options]' URL carries anything the log redaction would hide - a
  /// query key [ApiLoggingInterceptor.isSensitiveQueryKey] treats as a
  /// secret, or a nested one [ApiLoggingInterceptor.redactUrl] finds - or
  /// cannot be parsed.
  static bool _querySecret(RequestOptions options) {
    try {
      final uri = options.uri;
      if (uri.queryParametersAll.keys.any(
        ApiLoggingInterceptor.isSensitiveQueryKey,
      )) {
        return true;
      }
      final url = uri.toString();
      return ApiLoggingInterceptor.redactUrl(url) != url;
    } on FormatException {
      return true;
    }
  }

  /// Returns true when a session credential exists in the token store.
  ///
  /// Fails closed: if the store throws, the credential state is unknown and
  /// the request is treated as authenticated.
  Future<bool> _hasSessionCredential() async {
    final store = _tokenStore;
    if (store == null) {
      return false;
    }
    try {
      final token = await store.getAccessToken();
      return token != null && token.isNotEmpty;
    } on Object catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache credential check error: $e');
      }
      return true;
    }
  }

  /// `Vary` fields that cannot select a different body for this client:
  /// the HTTP stack decodes the content encoding before the body arrives, and
  /// the app's origin is fixed.
  static const Set<String> _varyFieldsTheKeyCovers = {
    'accept-encoding',
    'origin',
  };

  /// Whether the server marked [response] as not for this cache: a
  /// `Cache-Control` of `no-store`, `private` or `no-cache`, a
  /// `Pragma: no-cache`, a `Set-Cookie`, or a `Vary` field naming a request
  /// header other than [_varyFieldsTheKeyCovers].
  static bool _responseForbidsStorage(Response<dynamic> response) {
    List<String> directives(String header) =>
        (response.headers[header] ?? const <String>[])
            .expand((value) => value.split(','))
            .map((d) => d.trim().toLowerCase().split('=').first)
            .toList();
    const refusing = {'no-store', 'private', 'no-cache'};
    if (directives('cache-control').any(refusing.contains)) return true;
    if (directives('pragma').contains('no-cache')) return true;
    // Every other request-header field is outside this cache's URL-only
    // key. This includes Vary: *, multiple lines and mixed-case field names.
    if ((response.headers['vary'] ?? const <String>[])
        .expand((value) => value.split(','))
        .map((field) => field.trim().toLowerCase())
        .any(
          (field) =>
              field.isNotEmpty && !_varyFieldsTheKeyCovers.contains(field),
        )) {
      return true;
    }
    return response.headers['set-cookie']?.isNotEmpty ?? false;
  }

  /// The storage key for [options]: a SHA-256 of the full request URL, query
  /// included, so the URL itself - and any token in it - is never stored.
  @visibleForTesting
  static String cacheKeyFor(RequestOptions options) =>
      '$_cacheKeyPrefix'
      '${sha256.convert(utf8.encode(options.uri.toString()))}';

  /// Removes, once per interceptor, every entry no request would read or
  /// evict again:
  ///
  /// - entries stored under a verbatim-URL key, which can hold a query-string
  ///   secret;
  /// - every entry cached under an older sensitive-key rule
  ///   ([ApiLoggingInterceptor.sensitiveKeyRuleVersion]): a key that joined
  ///   the rule turns its URLs into secret queries, which bypass the cache,
  ///   so their old responses would stay in plaintext storage for good. The
  ///   URL is hashed, so which entries those are cannot be told; the cache is
  ///   disposable, and all of it goes.
  ///
  /// A failed purge disables cache use and is retried on the next request.
  Future<bool> _purgeLegacyEntries() {
    return _legacyPurge ??=
        _serializedIndexUpdate(() async {
          final index = await _readIndex();
          // Nothing cached, nothing to judge: the stamp is written with the
          // first entry (_addToIndex).
          if (index.isEmpty) return;
          final storedVersion = await _storageService.getInt(_ruleVersionKey);
          final ruleChanged =
              storedVersion != ApiLoggingInterceptor.sensitiveKeyRuleVersion;
          final stale = ruleChanged
              ? index
              : index.where((key) => !_hashedKey.hasMatch(key)).toList();
          for (final cacheKey in stale) {
            if (!await _storageService.remove(cacheKey) ||
                !await _storageService.remove(
                  '$_timestampKeyPrefix$cacheKey',
                )) {
              throw StateError('Cache purge deletion refused');
            }
          }
          if (stale.isNotEmpty) {
            final kept = index.where((key) => !stale.contains(key)).toList();
            if (kept.isEmpty) {
              if (!await _storageService.remove(_indexKey)) {
                throw StateError('Cache purge index removal refused');
              }
            } else {
              if (!await _storageService.setStringList(_indexKey, kept)) {
                throw StateError('Cache purge index update refused');
              }
            }
          }
          if (ruleChanged) {
            if (!await _storageService.setInt(
              _ruleVersionKey,
              ApiLoggingInterceptor.sensitiveKeyRuleVersion,
            )) {
              throw StateError('Cache purge version update refused');
            }
          }
        }).then((_) => true).catchError((Object e) {
          _legacyPurge = null;
          if (AppConfig.isDebugMode) {
            debugPrint('Cache legacy purge error: $e');
          }
          return false;
        });
  }

  /// Gets cached response if available and not expired
  Future<Map<String, dynamic>?> _getCachedResponse(String cacheKey) async {
    try {
      // A former write may have stored the body before its index update
      // failed. A policy upgrade cannot enumerate or certify that orphan.
      // Only indexed bodies admitted by the current policy may be reused.
      if (!(await _readIndex()).contains(cacheKey) ||
          await _storageService.getInt(_ruleVersionKey) !=
              ApiLoggingInterceptor.sensitiveKeyRuleVersion) {
        return null;
      }
      final cachedData = await _storageService.getString(cacheKey);
      if (cachedData == null) return null;

      final timestampKey = '$_timestampKeyPrefix$cacheKey';
      final timestampStr = await _storageService.getString(timestampKey);
      if (timestampStr == null) return null;

      // Absolute instants on both sides: the stored string names one
      // unambiguously, so the age does not move when the device's offset
      // does. An offset-less legacy string is still read as local wall
      // clock, exactly as DateTime.parse read it before.
      final timestamp = DateFormatter.parseIso8601(timestampStr);
      if (timestamp == null) {
        // Corrupt or out-of-range timestamp: there is no age to compute, so
        // drop the entry and report a miss rather than serve it on a guess.
        await _evictEntry(cacheKey, timestampKey);
        return null;
      }
      final now = DateTime.now().toUtc();
      final age = now.difference(timestamp);

      // Fresh first: an entry inside maxAge is served whatever maxStale says.
      final stale = age > _cacheConfig.maxAge;
      if (stale && age > _cacheConfig.maxStale) {
        // Too stale even as a fallback.
        await _evictEntry(cacheKey, timestampKey);
        return null;
      }

      final decodedData = JsonHelper.decode(cachedData);
      // Headers are not cached separately, return empty headers
      // In production, you might want to cache headers separately
      return {
        'data': decodedData,
        'headers': <String, List<String>>{},
        'stale': stale,
      };
    } on Object catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache read error: $e');
      }
      return null;
    }
  }

  /// Caches the response
  Future<void> _cacheResponse(
    String cacheKey,
    dynamic data,
    Map<String, List<String>> headers,
  ) async {
    try {
      final jsonData = JsonHelper.encode(data);
      if (jsonData == null) return;

      if (!await _storageService.setString(cacheKey, jsonData)) return;

      final timestampKey = '$_timestampKeyPrefix$cacheKey';
      if (!await _storageService.setString(
        timestampKey,
        DateFormatter.formatIso8601(DateTime.now()),
      )) {
        return;
      }

      await _addToIndex(cacheKey);
    } on Object catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache write error: $e');
      }
    }
  }

  /// Removes a cached body, its timestamp and its index entry.
  Future<void> _evictEntry(String cacheKey, String timestampKey) async {
    await _storageService.remove(cacheKey);
    await _storageService.remove(timestampKey);
    await _removeFromIndex(cacheKey);
  }

  Future<List<String>> _readIndex() async {
    return await _storageService.getStringList(_indexKey) ?? <String>[];
  }

  /// Tail of the index mutation queue.
  ///
  /// Every read-modify-write of the index chains onto this, so two cached
  /// GETs completing together cannot both read the same old index and let
  /// the last write drop the other's key - which left that body out of
  /// [clearCache] and so alive past a logout.
  ///
  /// Null while idle, so an idle interceptor never makes a caller wait on a
  /// future created earlier, possibly in another zone (a completed future
  /// delivers through its own zone's microtask queue, which a widget test's
  /// fake clock does not drain from inside `runAsync`).
  Future<void>? _indexQueue;

  /// Runs [update] only after every previously queued index update settled.
  /// A failed update does not wedge the queue.
  Future<void> _serializedIndexUpdate(Future<void> Function() update) async {
    final previous = _indexQueue;
    final done = Completer<void>();
    _indexQueue = done.future;
    try {
      if (previous != null) {
        await previous;
      }
      await update();
    } finally {
      done.complete();
      if (identical(_indexQueue, done.future)) _indexQueue = null;
    }
  }

  Future<void> _addToIndex(String cacheKey) {
    return _serializedIndexUpdate(() async {
      final index = await _readIndex();
      if (index.contains(cacheKey)) return;
      await _storageService.setStringList(_indexKey, [...index, cacheKey]);
      if (index.isEmpty) {
        // The rule this entry was cached under; see _purgeLegacyEntries.
        // After the index write: a failure here then leaves an indexed entry
        // with no stamp, which the next launch purges, rather than a body no
        // index lists.
        await _storageService.setInt(
          _ruleVersionKey,
          ApiLoggingInterceptor.sensitiveKeyRuleVersion,
        );
      }
    });
  }

  Future<void> _removeFromIndex(String cacheKey) {
    return _serializedIndexUpdate(() async {
      final index = await _readIndex();
      if (!index.contains(cacheKey)) return;
      final remaining = index.where((key) => key != cacheKey).toList();
      if (remaining.isEmpty) {
        await _storageService.remove(_indexKey);
        return;
      }
      await _storageService.setStringList(_indexKey, remaining);
    });
  }

  /// Clears every cached response.
  ///
  /// Walks the key index written by [_cacheResponse] and removes each body,
  /// its timestamp, and finally the index itself.
  ///
  /// Queued behind any index update in flight, so a key added just before
  /// the clear is in the index it walks.
  @override
  Future<void> clearCache() async {
    try {
      await _serializedIndexUpdate(() async {
        final index = await _readIndex();
        for (final cacheKey in index) {
          await _storageService.remove(cacheKey);
          await _storageService.remove('$_timestampKeyPrefix$cacheKey');
        }
        await _storageService.remove(_indexKey);
        await _storageService.remove(_ruleVersionKey);
      });
    } on Exception catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache clear error: $e');
      }
    }
  }
}
