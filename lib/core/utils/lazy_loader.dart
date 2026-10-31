import 'dart:async';

/// Utility for lazy loading and deferred imports
///
/// This class helps with lazy loading of features and resources,
/// reducing initial app startup time and memory footprint.
///
/// Example:
/// ```dart
/// final lazyLoader = LazyLoader<String, Widget>(
///   loader: (key) async {
///     // Load feature module
///     final module = await import('package:app/features/$key.dart');
///     return module.createWidget();
///   },
/// );
///
/// // Load when needed
/// final widget = await lazyLoader.load('feature_name');
/// ```
class LazyLoader<K, T> {
  /// Creates a [LazyLoader] with the given [loader] function
  LazyLoader({
    required Future<T> Function(K key) loader,
    this.cacheEnabled = true,
    this.maxCacheSize = 50,
  }) : _loader = loader,
       _cache = <K, T>{},
       _loadingFutures = <K, Future<T>>{};

  /// Loader function that loads the resource
  final Future<T> Function(K key) _loader;

  /// Whether to cache loaded resources
  final bool cacheEnabled;

  /// Maximum number of items to cache
  final int maxCacheSize;

  /// Cache of loaded resources
  final Map<K, T> _cache;

  /// Map of currently loading futures to prevent duplicate loads
  final Map<K, Future<T>> _loadingFutures;

  /// Advanced by [clearCache]; a load that finishes under an older value
  /// does not write to the cache.
  int _generation = 0;

  /// Keys [evict]ed while their load was in flight.
  final Set<K> _evictedWhileLoading = <K>{};

  /// Load a resource by key
  ///
  /// Returns cached value if available, otherwise loads it
  Future<T> load(K key) async {
    // Return cached value if available.
    // `as T` rather than `!`: a LazyLoader<K, T?> may legitimately cache a
    // null value, and the null-check operator threw on the second load.
    if (cacheEnabled && _cache.containsKey(key)) {
      return _cache[key] as T;
    }

    // Return existing loading future if already loading
    if (_loadingFutures.containsKey(key)) {
      return await _loadingFutures[key]!;
    }

    // Start loading
    final generation = _generation;
    _evictedWhileLoading.remove(key);
    final future = () async {
      // Yield before calling the loader, so the caller stores this future
      // first: a loader that throws before returning one would otherwise
      // clear the entry here before it is stored, and the stored failure
      // would be returned forever.
      await null;
      try {
        final value = await _loader(key);
        // Cache the result - unless the cache was cleared, or this key
        // evicted, while the load was in flight: writing it back would undo
        // that.
        final discarded =
            generation != _generation || _evictedWhileLoading.remove(key);
        if (cacheEnabled && !discarded) {
          _cache[key] = value;
          // Evict oldest entries if cache is full
          if (_cache.length > maxCacheSize) {
            final firstKey = _cache.keys.first;
            _cache.remove(firstKey);
          }
        }
        unawaited(_loadingFutures.remove(key));
        return value;
      } catch (error) {
        unawaited(_loadingFutures.remove(key));
        rethrow;
      }
    }();

    _loadingFutures[key] = future;
    return await future;
  }

  /// Preload a resource without waiting for it
  ///
  /// A failed preload is dropped, not left as an uncaught zone error - which
  /// a zone that rethrows turns into a crash, and a crash reporter files as
  /// one. Nothing is cached for the key, so a
  /// later [load] retries and surfaces the error to a caller who awaits it.
  void preload(K key) {
    if (!_cache.containsKey(key) && !_loadingFutures.containsKey(key)) {
      unawaited(load(key).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  /// Preload multiple resources
  void preloadMultiple(List<K> keys) {
    keys.forEach(preload);
  }

  /// Clear the cache, including what loads in flight would have written
  void clearCache() {
    _cache.clear();
    _generation++;
  }

  /// Remove a specific item from cache, including a load in flight for it
  void evict(K key) {
    _cache.remove(key);
    if (_loadingFutures.containsKey(key)) _evictedWhileLoading.add(key);
  }

  /// Get cache size
  int get cacheSize => _cache.length;

  /// Check if a key is cached
  bool isCached(K key) => _cache.containsKey(key);

  /// Check if a key is currently loading
  bool isLoading(K key) => _loadingFutures.containsKey(key);
}

/// Deferred import helper
///
/// This class helps with loading Dart deferred imports,
/// which can significantly reduce initial app size.
///
/// Example:
/// ```dart
/// // In your file:
/// import 'package:app/features/heavy_feature.dart' deferred as heavy;
///
/// // Use the helper:
/// final loader = DeferredImportLoader(
///   loadFunction: () => heavy.loadLibrary(),
/// );
///
/// await loader.load();
/// // Now you can use heavy.*
/// ```
class DeferredImportLoader {
  /// Creates a [DeferredImportLoader] with the given [loadFunction]
  DeferredImportLoader({required Future<void> Function() loadFunction})
    : _loadFunction = loadFunction;

  /// Function to load the deferred library
  final Future<void> Function() _loadFunction;

  /// Whether the library is loaded
  bool _isLoaded = false;

  /// Future for the loading operation
  Future<void>? _loadingFuture;

  /// Load the deferred library
  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    if (_loadingFuture != null) {
      return await _loadingFuture;
    }

    return await (_loadingFuture = () async {
      // Yield before calling the loader, so the caller stores this future
      // first: a loader that throws before returning one would otherwise
      // clear the entry here before it is stored, and the stored failure
      // would be returned forever.
      await null;
      try {
        await _loadFunction();
        _isLoaded = true;
        _loadingFuture = null;
      } catch (error) {
        _loadingFuture = null;
        rethrow;
      }
    }());
  }

  /// Check if the library is loaded
  bool get isLoaded => _isLoaded;

  /// Reset the loader (useful for testing)
  void reset() {
    _isLoaded = false;
    _loadingFuture = null;
  }
}

/// Lazy initialization helper
///
/// This class helps with lazy initialization of expensive resources.
///
/// Example:
/// ```dart
/// final lazyInit = LazyInitializer<ExpensiveResource>(
///   initializer: () => ExpensiveResource.create(),
/// );
///
/// // Initialize when needed
/// final resource = await lazyInit.get();
/// ```
class LazyInitializer<T> {
  /// Creates a [LazyInitializer] with the given [initializer]
  LazyInitializer({required Future<T> Function() initializer})
    : _initializer = initializer;

  /// Function to initialize the resource
  final Future<T> Function() _initializer;

  /// Cached instance
  T? _instance;

  /// Future for the initialization
  Future<T>? _initFuture;

  /// Get the instance, initializing if necessary
  Future<T> get() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_initFuture != null) {
      return await _initFuture!;
    }

    _initFuture = () async {
      // Yield before calling the loader, so the caller stores this future
      // first: a loader that throws before returning one would otherwise
      // clear the entry here before it is stored, and the stored failure
      // would be returned forever.
      await null;
      try {
        final value = await _initializer();
        _instance = value;
        _initFuture = null;
        return value;
      } catch (error) {
        _initFuture = null;
        rethrow;
      }
    }();

    return await _initFuture!;
  }

  /// Check if initialized
  bool get isInitialized => _instance != null;

  /// Reset the initializer (useful for testing)
  void reset() {
    _instance = null;
    _initFuture = null;
  }
}
