import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/json_helper.dart';

/// Cache configuration for HTTP responses
class CacheConfig {
  /// Creates a [CacheConfig] with the given parameters
  const CacheConfig({
    this.maxAge = const Duration(hours: 1),
    this.maxStale = const Duration(days: 7),
    this.enableCache = true,
  });

  /// Maximum age for cached responses
  final Duration maxAge;

  /// Maximum stale time for cached responses
  final Duration maxStale;

  /// Whether caching is enabled
  final bool enableCache;
}

/// Interceptor for caching HTTP responses.
///
/// ## What is cached
///
/// Only **unauthenticated** `GET` responses with status 200. Before touching
/// the cache - on read and on write - the interceptor asks the [ITokenStore]
/// whether a session credential exists. If one does, the request neither
/// reads from nor writes to the cache and goes straight to the network.
///
/// The credential check deliberately reads the token store rather than
/// sniffing `options.headers` for `Authorization`. `AuthInterceptor` writes
/// that header from its own `onRequest`, and dio runs `onRequest` in
/// registration order, so a header sniff only works while this interceptor
/// happens to be registered *after* `AuthInterceptor` - an invariant nothing
/// enforces, on a surface koniz-dev/flutter-starter#46 already proved is easy
/// to get wrong. Reading the same store `AuthInterceptor` reads makes the
/// decision correct at any position in the chain. The header check is kept as
/// a secondary guard for credentials a caller attaches by hand through
/// `Options(headers: ...)`, which *are* already present this early.
///
/// ## Where it is stored
///
/// In [StorageService], i.e. `shared_preferences` - plaintext, readable on a
/// rooted or jailbroken device and included in unencrypted device backups.
/// That is acceptable only because nothing authenticated ever lands there. Do
/// not relax the credential check without moving to encrypted storage.
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

  /// Headers that should not be cached
  static const List<String> _noCacheHeaders = ['authorization', 'cookie'];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
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
    final cacheKey = _getCacheKey(options);
    final cachedData = await _getCachedResponse(cacheKey);

    if (cachedData != null) {
      // Return cached response
      final headers = cachedData['headers'] as Map<String, List<String>>?;
      final cachedResponse = Response<dynamic>(
        data: cachedData['data'],
        statusCode: 200,
        requestOptions: options,
        headers: Headers.fromMap(headers ?? <String, List<String>>{}),
      );

      return handler.resolve(cachedResponse);
    }

    super.onRequest(options, handler);
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

    // Check if response should be cached
    if (await _shouldBypassCache(requestOptions)) {
      return super.onResponse(response, handler);
    }

    // Cache the response
    final cacheKey = _getCacheKey(requestOptions);
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

    // Secondary guard: a credential the caller attached directly to the
    // request is visible here regardless of interceptor order.
    for (final header in _noCacheHeaders) {
      if (options.headers.containsKey(header)) {
        return true;
      }
    }

    // Primary guard: never touch the cache while a session credential exists.
    return _hasSessionCredential();
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

  /// Gets the cache key for the request
  String _getCacheKey(RequestOptions options) {
    final uri = options.uri.toString();
    final queryParams = options.queryParameters.toString();
    return '$_cacheKeyPrefix${uri}_$queryParams';
  }

  /// Gets cached response if available and not expired
  Future<Map<String, dynamic>?> _getCachedResponse(String cacheKey) async {
    try {
      final cachedData = await _storageService.getString(cacheKey);
      if (cachedData == null) return null;

      final timestampKey = '$_timestampKeyPrefix$cacheKey';
      final timestampStr = await _storageService.getString(timestampKey);
      if (timestampStr == null) return null;

      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      final age = now.difference(timestamp);

      // Check if cache is still valid
      if (age > _cacheConfig.maxAge) {
        // Cache expired, check if stale cache is acceptable
        if (age > _cacheConfig.maxStale) {
          // Too stale, remove cache
          await _storageService.remove(cacheKey);
          await _storageService.remove(timestampKey);
          await _removeFromIndex(cacheKey);
          return null;
        }
        // Stale but acceptable (can be used with warning in production)
      }

      final decodedData = JsonHelper.decode(cachedData);
      // Headers are not cached separately, return empty headers
      // In production, you might want to cache headers separately
      return {'data': decodedData, 'headers': <String, List<String>>{}};
    } on Exception catch (e) {
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

      await _storageService.setString(cacheKey, jsonData);

      final timestampKey = '$_timestampKeyPrefix$cacheKey';
      await _storageService.setString(
        timestampKey,
        DateTime.now().toIso8601String(),
      );

      await _addToIndex(cacheKey);
    } on Exception catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache write error: $e');
      }
    }
  }

  Future<List<String>> _readIndex() async {
    return await _storageService.getStringList(_indexKey) ?? <String>[];
  }

  Future<void> _addToIndex(String cacheKey) async {
    final index = await _readIndex();
    if (index.contains(cacheKey)) return;
    await _storageService.setStringList(_indexKey, [...index, cacheKey]);
  }

  Future<void> _removeFromIndex(String cacheKey) async {
    final index = await _readIndex();
    if (!index.contains(cacheKey)) return;
    final remaining = index.where((key) => key != cacheKey).toList();
    if (remaining.isEmpty) {
      await _storageService.remove(_indexKey);
      return;
    }
    await _storageService.setStringList(_indexKey, remaining);
  }

  /// Clears every cached response.
  ///
  /// Walks the key index written by [_cacheResponse] and removes each body,
  /// its timestamp, and finally the index itself.
  @override
  Future<void> clearCache() async {
    try {
      final index = await _readIndex();
      for (final cacheKey in index) {
        await _storageService.remove(cacheKey);
        await _storageService.remove('$_timestampKeyPrefix$cacheKey');
      }
      await _storageService.remove(_indexKey);
    } on Exception catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache clear error: $e');
      }
    }
  }
}
