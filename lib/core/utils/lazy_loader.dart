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
  })  : _loader = loader,
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

  /// Load a resource by key
  ///
  /// Returns cached value if available, otherwise loads it
  Future<T> load(K key) async {
    // Return cached value if available
    if (cacheEnabled && _cache.containsKey(key)) {
      return _cache[key]!;
    }

    // Return existing loading future if already loading
    if (_loadingFutures.containsKey(key)) {
      return _loadingFutures[key]!;
    }

    // Start loading
    final future = () async {
      try {
        final value = await _loader(key);
        // Cache the result
        if (cacheEnabled) {
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
    return future;
  }

  /// Preload a resource without waiting for it
  void preload(K key) {
    if (!_cache.containsKey(key) && !_loadingFutures.containsKey(key)) {
      unawaited(load(key));
    }
  }

  /// Preload multiple resources
  void preloadMultiple(List<K> keys) {
    keys.forEach(preload);
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
  }

  /// Remove a specific item from cache
  void evict(K key) {
    _cache.remove(key);
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
  DeferredImportLoader({
    required Future<void> Function() loadFunction,
  }) : _loadFunction = loadFunction;

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
      return _loadingFuture;
    }

    return _loadingFuture = () async {
      try {
        await _loadFunction();
        _isLoaded = true;
        _loadingFuture = null;
      } catch (error) {
        _loadingFuture = null;
        rethrow;
      }
    }();
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
  LazyInitializer({
    required Future<T> Function() initializer,
  }) : _initializer = initializer;

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
      return _initFuture!;
    }

    _initFuture = () async {
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

    return _initFuture!;
  }

  /// Check if initialized
  bool get isInitialized => _instance != null;

  /// Reset the initializer (useful for testing)
  void reset() {
    _instance = null;
    _initFuture = null;
  }
}
