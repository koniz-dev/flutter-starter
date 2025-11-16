import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Helper class for memory management and leak detection
///
/// This class provides utilities for managing memory, detecting potential
/// leaks, and optimizing memory usage.
class MemoryHelper {
  MemoryHelper._();

  /// Clears image cache to free memory
  static void clearImageCache() {
    imageCache
      ..clear()
      ..clearLiveImages();
  }

  /// Forces garbage collection (debug only)
  ///
  /// Note: This is only available in debug mode and may not work on all
  /// platforms
  static void forceGC() {
    if (kDebugMode) {
      // Note: Dart doesn't provide direct GC control
      // This is a placeholder for future implementation
      debugPrint('Memory: Attempting to free memory');
    }
  }

  /// Gets memory usage information
  ///
  /// Returns a map with memory statistics
  static Map<String, dynamic> getMemoryInfo() {
    return {
      'imageCacheSize': imageCache.currentSize,
      'imageCacheSizeBytes': imageCache.currentSizeBytes,
      'imageCacheMaxSize': imageCache.maximumSize,
      'imageCacheMaxSizeBytes': imageCache.maximumSizeBytes,
    };
  }

  /// Optimizes image cache settings
  ///
  /// [maxSize] - Maximum number of images to cache
  /// [maxSizeBytes] - Maximum cache size in bytes
  static void optimizeImageCache({
    int? maxSize,
    int? maxSizeBytes,
  }) {
    if (maxSize != null) {
      imageCache.maximumSize = maxSize;
    }
    if (maxSizeBytes != null) {
      imageCache.maximumSizeBytes = maxSizeBytes;
    }
  }

  /// Disposes of resources properly
  ///
  /// Call this when the app is being closed or memory is low
  static Future<void> disposeResources() async {
    clearImageCache();
    forceGC();
  }
}

/// Typedef for disposable resources
typedef Disposable = void Function();

/// Mixin for automatic disposal tracking
///
/// Use this mixin in StatefulWidget states to track disposal
mixin DisposalTracker<T extends StatefulWidget> on State<T> {
  final List<Disposable> _disposables = [];

  /// Registers a disposable resource
  void registerDisposable(Disposable disposable) {
    _disposables.add(disposable);
  }

  @override
  void dispose() {
    for (final disposable in _disposables) {
      disposable();
    }
    _disposables.clear();
    super.dispose();
  }
}
