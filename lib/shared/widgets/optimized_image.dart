import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/image_cache_helper.dart';

/// Optimized image widget with automatic caching and error handling
///
/// This widget provides:
/// - Automatic image caching
/// - Placeholder while loading
/// - Error handling with fallback
/// - Memory-efficient loading, decoded at the device's real pixel density
/// - Optional preloading, fired once per URL rather than on every rebuild
///
/// Example:
/// ```dart
/// OptimizedImage(
///   imageUrl: 'https://example.com/image.jpg',
///   semanticLabel: 'Profile photo',
///   placeholder: CircularProgressIndicator(),
///   errorWidget: Icon(Icons.error),
/// )
/// ```
class OptimizedImage extends StatefulWidget {
  /// Creates an [OptimizedImage] widget
  const OptimizedImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.semanticLabel,
    this.preload = false,
    super.key,
  });

  /// URL of the image to load
  final String imageUrl;

  /// Optional width constraint, in logical pixels
  final double? width;

  /// Optional height constraint, in logical pixels
  final double? height;

  /// How the image should be inscribed into the available space
  final BoxFit fit;

  /// Widget to show while image is loading
  final Widget? placeholder;

  /// Widget to show if image fails to load
  final Widget? errorWidget;

  /// Alt text announced by screen readers
  ///
  /// When null the image is treated as decorative and excluded from the
  /// semantics tree, rather than surfacing as an unlabeled node.
  final String? semanticLabel;

  /// Whether to preload the image before displaying
  ///
  /// The preload fires once per [imageUrl], not on every rebuild.
  final bool preload;

  /// Test seam for observing preloads without touching the network.
  ///
  /// When non-null it replaces [ImageCacheHelper.preloadImage]. Tests must
  /// reset it, and nothing in `lib/` may set it.
  @visibleForTesting
  static Future<bool> Function(String url, {BuildContext? context})?
  debugPreloader;

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  String? _preloadedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePreload();
  }

  @override
  void didUpdateWidget(OptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _preloadedUrl = null;
    }
    _maybePreload();
  }

  void _maybePreload() {
    if (!widget.preload ||
        widget.imageUrl.isEmpty ||
        _preloadedUrl == widget.imageUrl) {
      return;
    }
    // Recorded before awaiting so a rebuild during the load does not re-fire
    // it - the old `StatelessWidget` retried a failing URL on every rebuild.
    _preloadedUrl = widget.imageUrl;
    final preloader =
        OptimizedImage.debugPreloader ?? ImageCacheHelper.preloadImage;
    unawaited(preloader(widget.imageUrl, context: context));
  }

  @override
  Widget build(BuildContext context) {
    // `cacheWidth`/`cacheHeight` are in PHYSICAL pixels while `width`/`height`
    // are logical, so decoding at the logical size alone produced a bitmap
    // `devicePixelRatio` times too small - visibly blurry on any modern phone.
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Image.network(
      widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.semanticLabel == null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return widget.placeholder ??
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
        return widget.errorWidget ??
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            );
      },
      cacheWidth: _physicalPixels(widget.width, devicePixelRatio),
      cacheHeight: _physicalPixels(widget.height, devicePixelRatio),
    );
  }

  static int? _physicalPixels(double? logical, double devicePixelRatio) {
    if (logical == null || !logical.isFinite || logical <= 0) {
      return null;
    }
    return (logical * devicePixelRatio).round();
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
    this.semanticLabel,
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

  /// Alt text announced by screen readers
  ///
  /// When null the image is treated as decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: OptimizedImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
