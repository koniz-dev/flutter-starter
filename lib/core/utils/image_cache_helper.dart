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

  /// Default bound on a single preload.
  static const Duration defaultPreloadTimeout = Duration(seconds: 10);

  /// Preloads an image from a URL
  ///
  /// This is useful for preloading images that will be displayed soon,
  /// such as images in a list that's about to scroll into view.
  ///
  /// Prefer passing a real [BuildContext] from your widget when available
  /// so [precacheImage] can integrate with the element tree. When [context]
  /// is omitted, loading uses [ImageProvider.resolve] (no dummy context).
  ///
  /// [timeout] bounds the wait. An image server that accepts the connection
  /// and then stalls never calls either callback, so without a timeout the
  /// returned future never completes.
  ///
  /// Returns true if successful, false otherwise.
  static Future<bool> preloadImage(
    String url, {
    BuildContext? context,
    Duration timeout = defaultPreloadTimeout,
  }) async {
    if (url.isEmpty) {
      return false;
    }

    final imageProvider = NetworkImage(url);
    try {
      if (context != null) {
        // precacheImage swallows the failure through onError, so the only
        // way to report it is to record that onError fired. Returning true
        // unconditionally reported every 404 as a successful preload.
        var failed = false;
        await precacheImage(
          imageProvider,
          context,
          onError: (e, stack) {
            failed = true;
            debugPrint('Preload error: $e');
          },
        ).timeout(
          timeout,
          onTimeout: () {
            failed = true;
            debugPrint('Preload timed out after $timeout: $url');
          },
        );
        return !failed;
      }
      return await _preloadViaImageStream(imageProvider, timeout);
    } on Object catch (e) {
      debugPrint('Failed to preload image: $url, error: $e');
      return false;
    }
  }

  static Future<bool> _preloadViaImageStream(
    ImageProvider<Object> provider,
    Duration timeout,
  ) {
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
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        stream.removeListener(listener);
        debugPrint('Preload timed out after $timeout');
        return false;
      },
    );
  }

  /// Preloads multiple images
  ///
  /// The URLs are preloaded concurrently. Awaiting them one at a time meant
  /// a single slow image blocked every image behind it in the batch.
  ///
  /// Returns the number of successfully preloaded images.
  static Future<int> preloadImages(
    List<String> urls, {
    Duration timeout = defaultPreloadTimeout,
  }) async {
    if (urls.isEmpty) return 0;
    final results = await Future.wait(
      urls.map((url) => preloadImage(url, timeout: timeout)),
    );
    return results.where((ok) => ok).length;
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
