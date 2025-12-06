import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/image_cache_helper.dart';

/// Optimized image widget with automatic caching and error handling
///
/// This widget provides:
/// - Automatic image caching
/// - Placeholder while loading
/// - Error handling with fallback
/// - Memory-efficient loading
/// - Optional preloading
///
/// Example:
/// ```dart
/// OptimizedImage(
///   imageUrl: 'https://example.com/image.jpg',
///   placeholder: CircularProgressIndicator(),
///   errorWidget: Icon(Icons.error),
/// )
/// ```
class OptimizedImage extends StatelessWidget {
  /// Creates an [OptimizedImage] widget
  const OptimizedImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.cacheKey,
    this.preload = false,
    super.key,
  });

  /// URL of the image to load
  final String imageUrl;

  /// Optional width constraint
  final double? width;

  /// Optional height constraint
  final double? height;

  /// How the image should be inscribed into the available space
  final BoxFit fit;

  /// Widget to show while image is loading
  final Widget? placeholder;

  /// Widget to show if image fails to load
  final Widget? errorWidget;

  /// Optional cache key for the image
  final String? cacheKey;

  /// Whether to preload the image before displaying
  final bool preload;

  @override
  Widget build(BuildContext context) {
    if (preload && imageUrl.isNotEmpty) {
      // Preload image in background
      unawaited(ImageCacheHelper.preloadImage(imageUrl));
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      key: cacheKey != null ? Key(cacheKey!) : null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholder ??
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            );
      },
      // Enable caching
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
    );
  }
}

/// Optimized image with automatic aspect ratio preservation
class OptimizedAspectImage extends StatelessWidget {
  /// Creates an [OptimizedAspectImage] widget
  const OptimizedAspectImage({
    required this.imageUrl,
    required this.aspectRatio,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.cacheKey,
    super.key,
  });

  /// URL of the image to load
  final String imageUrl;

  /// Aspect ratio to maintain
  final double aspectRatio;

  /// How the image should be inscribed into the available space
  final BoxFit fit;

  /// Widget to show while image is loading
  final Widget? placeholder;

  /// Widget to show if image fails to load
  final Widget? errorWidget;

  /// Optional cache key for the image
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: OptimizedImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        cacheKey: cacheKey,
      ),
    );
  }
}
