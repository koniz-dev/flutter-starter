import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for automatic provider disposal tracking
///
/// Use this mixin in ConsumerStatefulWidget states to automatically
/// track and dispose of providers and resources.
///
/// Example:
/// ```dart
/// class MyScreenState extends ConsumerState<MyScreen>
///     with ProviderDisposal {
///   @override
///   void initState() {
///     super.initState();
///     // Providers are automatically tracked
///   }
///
///   // Resources are automatically disposed
/// }
/// ```
mixin ProviderDisposal<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// List of disposables to clean up
  final List<Disposable> _disposables = [];

  /// Register a disposable resource
  ///
  /// The resource will be automatically disposed when the widget is disposed
  void registerDisposable(Disposable disposable) {
    _disposables.add(disposable);
  }

  @override
  void dispose() {
    // Dispose all registered resources
    for (final disposable in _disposables) {
      try {
        disposable();
      } on Object catch (_) {
        // Ignore disposal errors
      }
    }
    _disposables.clear();

    // Deliberately does NOT touch the global image cache. It used to call
    // MemoryHelper.clearImageCache() whenever the cache was above 80% full,
    // which evicted images still mounted on the screen underneath this one.
    // Global cache pressure is not one widget's business; call
    // MemoryHelper.clearImageCache() explicitly if you want that.

    super.dispose();
  }
}

/// Typedef for disposable resources
typedef Disposable = void Function();

/// Helper class for managing provider lifecycle
class ProviderLifecycleManager {
  ProviderLifecycleManager._();

  /// Dispose of a provider container
  ///
  /// This should be called when the app is closing or when
  /// you want to free up resources
  static void disposeContainer(dynamic container) {
    if (container is ProviderContainer) {
      container.dispose();
    }
  }

  /// Clear all provider caches
  ///
  /// This can help free memory in low-memory situations
  static void clearCaches(dynamic container) {
    // Riverpod doesn't expose cache clearing directly,
    // but we can dispose and recreate if needed
    // For now, this is a placeholder for future implementation
  }
}
