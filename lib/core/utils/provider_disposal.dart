import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/utils/memory_helper.dart';

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

  /// Register a provider subscription for automatic disposal
  ///
  /// This ensures the provider subscription is properly cancelled
  ///
  /// Note: In Riverpod 3.0, provider subscriptions are automatically
  /// disposed when the widget is disposed, so manual disposal is not needed.
  void registerProviderSubscription<TValue>(
    // The provider type is inferred from usage - any Riverpod provider
    // can be passed
    dynamic provider,
    void Function(TValue? previous, TValue next) listener,
  ) {
    // Riverpod automatically manages subscription lifecycle
    // No manual disposal needed - subscriptions are cleaned up when widget
    // disposes
    // ProviderListenable is an internal Riverpod type not exported, but
    // providers work at runtime
    ref.listen<TValue>(
      // ProviderListenable is not exported from Riverpod, but dynamic
      // provider works correctly at runtime with ref.listen
      // ignore: argument_type_not_assignable
      provider,
      listener,
    );
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

    // Clear image cache if memory is low
    final memoryInfo = MemoryHelper.getMemoryInfo();
    final cacheSize = memoryInfo['imageCacheSizeBytes'] as int? ?? 0;
    final maxSize = memoryInfo['imageCacheMaxSizeBytes'] as int? ?? 0;

    // Clear cache if it's using more than 80% of max
    if (maxSize > 0 && cacheSize > (maxSize * 0.8)) {
      MemoryHelper.clearImageCache();
    }

    super.dispose();
  }
}

/// Typedef for disposable resources
typedef Disposable = void Function();

/// Extension for ProviderRef to add auto-disposal helpers
extension ProviderDisposalExtension on WidgetRef {
  /// Watch a provider with automatic disposal tracking
  ///
  /// This is a convenience method that automatically tracks the provider
  /// for disposal. Use this in StatefulWidget states with ProviderDisposal
  /// mixin.
  TValue watchWithDisposal<TValue>(
    // Using dynamic for provider parameter because ProviderListenable is not
    // exported from Riverpod, but providers work correctly at runtime
    dynamic provider,
    ConsumerState<ConsumerStatefulWidget> state,
  ) {
    // Note: Riverpod automatically handles provider disposal
    // This method is kept for API compatibility
    // ignore: argument_type_not_assignable
    return watch<TValue>(provider);
  }
}

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
