import 'dart:async';

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
  /// such as images in a list that's about to scroll into view.
  ///
  /// Prefer passing a real [BuildContext] from your widget when available
  /// so [precacheImage] can integrate with the element tree. When [context]
  /// is omitted, loading uses [ImageProvider.resolve] (no dummy context).
  ///
  /// Returns true if successful, false otherwise.
  static Future<bool> preloadImage(String url, {BuildContext? context}) async {
    if (url.isEmpty) {
      return false;
    }

    final imageProvider = NetworkImage(url);
    try {
      if (context != null) {
        await precacheImage(
          imageProvider,
          context,
          onError: (e, stack) => debugPrint('Preload error: $e'),
        );
        return true;
      }
      return await _preloadViaImageStream(imageProvider);
    } on Object catch (e) {
      debugPrint('Failed to preload image: $url, error: $e');
      return false;
    }
  }

  static Future<bool> _preloadViaImageStream(ImageProvider<Object> provider) {
    final completer = Completer<bool>();
    late final ImageStream stream;
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onError: (exception, stackTrace) {
        stream.removeListener(listener);
        debugPrint('Preload error: $exception');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );
    stream = provider.resolve(ImageConfiguration.empty)..addListener(listener);
    return completer.future;
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
}
