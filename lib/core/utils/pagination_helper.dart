import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pagination configuration
class PaginationConfig {
  /// Creates a [PaginationConfig] with the given parameters
  const PaginationConfig({
    this.pageSize = 20,
    this.initialPage = 1,
    this.enablePrefetch = true,
    this.prefetchThreshold = 0.8,
  });

  /// Number of items per page
  final int pageSize;

  /// Initial page number (usually 1)
  final int initialPage;

  /// Whether to prefetch next page before user reaches end
  final bool enablePrefetch;

  /// Threshold (0.0-1.0) for prefetching next page
  /// 0.8 means prefetch when 80% of current page is scrolled
  final double prefetchThreshold;
}

/// Pagination state
class PaginationState<T> {
  /// Creates a [PaginationState] with the given parameters
  PaginationState({
    required this.items,
    required this.currentPage,
    required this.hasMore,
    this.isLoading = false,
    this.error,
  });

  /// All loaded items
  final List<T> items;

  /// Current page number
  final int currentPage;

  /// Whether there are more items to load
  final bool hasMore;

  /// Whether a page is currently loading
  final bool isLoading;

  /// Error message if loading failed
  final String? error;

  /// Creates a copy with updated values
  PaginationState<T> copyWith({
    List<T>? items,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Creates a new state with items appended
  PaginationState<T> appendPage(List<T> newItems, {required bool hasMore}) {
    return PaginationState<T>(
      items: [...items, ...newItems],
      currentPage: currentPage + 1,
      hasMore: hasMore,
    );
  }

  /// Creates a new state with loading flag
  PaginationState<T> setLoading({required bool loading}) {
    return copyWith(isLoading: loading);
  }

  /// Creates a new state with error
  PaginationState<T> setError(String errorMessage) {
    return copyWith(
      error: errorMessage,
    );
  }

  /// Resets pagination to initial state
  PaginationState<T> reset() {
    return PaginationState<T>(
      items: [],
      currentPage: 1,
      hasMore: true,
    );
  }
}

/// Helper class for managing pagination
///
/// This class provides utilities for implementing pagination in lists,
/// including automatic prefetching and state management.
///
/// Example:
/// ```dart
/// final paginationHelper = PaginationHelper<int>(
///   config: const PaginationConfig(pageSize: 20),
///   loadPage: (page) async {
///     final response = await api.getItems(page: page, limit: 20);
///     return (response.items, response.hasMore);
///   },
/// );
///
/// // Load first page
/// await paginationHelper.loadNextPage();
///
/// // Check if should prefetch
/// if (paginationHelper.shouldPrefetch(scrollPosition)) {
///   await paginationHelper.loadNextPage();
/// }
/// ```
class PaginationHelper<T> {
  /// Creates a [PaginationHelper] with the given [config] and [loadPage]
  /// callback
  PaginationHelper({
    required this.loadPage,
    PaginationConfig? config,
  }) : _config = config ?? const PaginationConfig();

  /// Configuration for pagination
  final PaginationConfig _config;

  /// Callback to load a page of items
  ///
  /// Should return a tuple of (items, hasMore)
  final Future<(List<T>, bool)> Function(int page) loadPage;

  /// Current pagination state
  PaginationState<T> _state = PaginationState<T>(
    items: [],
    currentPage: 1,
    hasMore: true,
  );

  /// Get current state
  PaginationState<T> get state => _state;

  /// Load the next page
  Future<void> loadNextPage() async {
    if (_state.isLoading || !_state.hasMore) {
      return;
    }

    _state = _state.setLoading(loading: true);

    try {
      final (items, hasMore) = await loadPage(_state.currentPage);
      _state = _state.appendPage(items, hasMore: hasMore);
    } on Object catch (e) {
      _state = _state.setError(
        e.toString(),
      ).setLoading(loading: false);
      if (kDebugMode) {
        debugPrint('Pagination error: $e');
      }
    }
  }

  /// Reset pagination to initial state
  void reset() {
    _state = _state.reset();
  }

  /// Check if should prefetch next page based on scroll position
  ///
  /// [scrollPosition] - Current scroll position (0.0 to 1.0)
  bool shouldPrefetch(double scrollPosition) {
    if (!_config.enablePrefetch) {
      return false;
    }

    return scrollPosition >= _config.prefetchThreshold &&
        !_state.isLoading &&
        _state.hasMore;
  }

  /// Check if should load next page (user reached end)
  bool shouldLoadNextPage(double scrollPosition) {
    return scrollPosition >= 1.0 && !_state.isLoading && _state.hasMore;
  }
}

/// Extension for ScrollController to check pagination
extension PaginationScrollExtension on ScrollController {
  /// Get scroll position as a ratio (0.0 to 1.0)
  double get scrollRatio {
    if (!hasClients || position.maxScrollExtent == 0) {
      return 0;
    }
    return position.pixels / position.maxScrollExtent;
  }

  /// Check if scrolled near the end (for prefetching)
  bool get isNearEnd {
    const threshold = 0.8;
    return scrollRatio >= threshold;
  }

  /// Check if scrolled to the end
  bool get isAtEnd {
    return scrollRatio >= 1.0;
  }
}
