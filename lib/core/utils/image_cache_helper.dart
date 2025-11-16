import 'package:flutter/material.dart';

/// Helper class for managing image caching
///
/// This class provides utilities for preloading, caching, and managing
/// images to improve performance and reduce network requests.
///
/// Uses Flutter's built-in image cache for efficient memory management.
class ImageCacheHelper {
  ImageCacheHelper._();

  /// Preloads an image from a URL
  ///
  /// This is useful for preloading images that will be displayed soon,
  /// such as images in a list that's about to be scrolled into view.
  ///
  /// Returns true if successful, false otherwise.
  static Future<bool> preloadImage(String url) async {
    try {
      final imageProvider = NetworkImage(url);
      await precacheImage(imageProvider, _getImageContext());
      return true;
    } on Exception catch (e) {
      debugPrint('Failed to preload image: $url, error: $e');
      return false;
    }
  }

  /// Preloads multiple images
  ///
  /// Returns the number of successfully preloaded images.
  static Future<int> preloadImages(List<String> urls) async {
    var successCount = 0;
    for (final url in urls) {
      if (await preloadImage(url)) {
        successCount++;
      }
    }
    return successCount;
  }

  /// Clears the image cache
  ///
  /// This clears both the live image cache and the pending image cache.
  static void clearCache() {
    imageCache
      ..clear()
      ..clearLiveImages();
  }

  /// Gets the maximum cache size
  ///
  /// Returns the maximum number of images that can be cached.
  static int get maxCacheSize => imageCache.maximumSize;

  /// Sets the maximum cache size
  ///
  /// [size] - Maximum number of images to cache (default: 1000)
  static set maxCacheSize(int size) {
    imageCache.maximumSize = size;
  }

  /// Gets the maximum cache size in bytes
  ///
  /// Returns the maximum cache size in bytes.
  static int get maxCacheBytes => imageCache.maximumSizeBytes;

  /// Sets the maximum cache size in bytes
  ///
  /// [bytes] - Maximum cache size in bytes (default: 100MB)
  static set maxCacheBytes(int bytes) {
    imageCache.maximumSizeBytes = bytes;
  }

  /// Gets the current cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'currentSize': imageCache.currentSize,
      'currentSizeBytes': imageCache.currentSizeBytes,
      'maximumSize': imageCache.maximumSize,
      'maximumSizeBytes': imageCache.maximumSizeBytes,
    };
  }

  /// Gets a BuildContext for image precaching
  ///
  /// This is a workaround since precacheImage requires a BuildContext.
  /// In production, you should pass the actual context from your widget.
  static BuildContext _getImageContext() {
    // This is a fallback - in practice, you should pass context from widget
    return _ImageCacheContext();
  }
}

/// Dummy context for image precaching
///
/// This is a workaround and should be replaced with actual context in
/// production
class _ImageCacheContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
