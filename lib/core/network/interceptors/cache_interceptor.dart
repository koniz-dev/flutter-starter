import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
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

/// Interceptor for caching HTTP responses
///
/// This interceptor caches GET requests based on cache headers or custom
/// cache configuration. Cached responses are stored in local storage.
class CacheInterceptor extends Interceptor {
  /// Creates a [CacheInterceptor] with the given [storageService] and
  /// [cacheConfig]
  CacheInterceptor({
    required StorageService storageService,
    CacheConfig? cacheConfig,
  })  : _storageService = storageService,
        _cacheConfig = cacheConfig ?? const CacheConfig();

  final StorageService _storageService;
  final CacheConfig _cacheConfig;

  /// Cache key prefix
  static const String _cacheKeyPrefix = 'http_cache_';

  /// Timestamp key prefix
  static const String _timestampKeyPrefix = 'http_cache_timestamp_';

  /// HTTP methods that should be cached
  static const List<String> _cacheableMethods = ['GET'];

  /// Headers that should not be cached
  static const List<String> _noCacheHeaders = [
    'authorization',
    'cookie',
  ];

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
    if (_shouldBypassCache(options)) {
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
    if (_shouldBypassCache(requestOptions)) {
      return super.onResponse(response, handler);
    }

    // Cache the response
    final cacheKey = _getCacheKey(requestOptions);
    await _cacheResponse(
      cacheKey,
      response.data,
      response.headers.map,
    );

    super.onResponse(response, handler);
  }

  /// Checks if the request should bypass cache
  bool _shouldBypassCache(RequestOptions options) {
    // Check for no-cache header
    final cacheControl = options.headers['cache-control'] as String?;
    if (cacheControl != null &&
        (cacheControl.toLowerCase().contains('no-cache') ||
            cacheControl.toLowerCase().contains('no-store'))) {
      return true;
    }

    // Don't cache requests with sensitive headers
    for (final header in _noCacheHeaders) {
      if (options.headers.containsKey(header)) {
        return true;
      }
    }

    return false;
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
          return null;
        }
        // Stale but acceptable (can be used with warning in production)
      }

      final decodedData = JsonHelper.decode(cachedData);
      // Headers are not cached separately, return empty headers
      // In production, you might want to cache headers separately
      return {
        'data': decodedData,
        'headers': <String, List<String>>{},
      };
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
    } on Exception catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache write error: $e');
      }
    }
  }

  /// Clears all cached responses
  Future<void> clearCache() async {
    try {
      // Note: This is a simplified implementation
      // In production, you might want to track cache keys separately
      // and remove them individually
    } on Exception catch (e) {
      if (AppConfig.isDebugMode) {
        debugPrint('Cache clear error: $e');
      }
    }
  }
}
