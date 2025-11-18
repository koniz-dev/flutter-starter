import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/pagination_helper.dart'
    show PaginationScrollExtension;

/// Optimized ListView with pagination support
///
/// This widget provides:
/// - Automatic pagination
/// - Prefetching support
/// - Performance optimizations
/// - Loading and error states
///
/// Example:
/// ```dart
/// OptimizedListView<Item>(
///   items: items,
///   itemBuilder: (context, item) => ItemWidget(item),
///   onLoadMore: () async {
///     final moreItems = await loadMoreItems();
///     return (moreItems, hasMore);
///   },
///   hasMore: hasMore,
/// )
/// ```
class OptimizedListView<T> extends StatefulWidget {
  /// Creates an [OptimizedListView] widget
  const OptimizedListView({
    required this.items,
    required this.itemBuilder,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.itemExtent,
    this.padding,
    this.scrollController,
    this.enablePrefetch = true,
    this.prefetchThreshold = 0.8,
    super.key,
  });

  /// List of items to display
  final List<T> items;

  /// Builder for each item
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Callback to load more items
  ///
  /// Should return a tuple of (items, hasMore)
  final Future<(List<T>, bool)> Function()? onLoadMore;

  /// Whether there are more items to load
  final bool hasMore;

  /// Whether currently loading more items
  final bool isLoading;

  /// Error message if loading failed
  final String? error;

  /// Callback to retry loading
  final VoidCallback? onRetry;

  /// Fixed height for each item (improves performance)
  final double? itemExtent;

  /// Padding around the list
  final EdgeInsets? padding;

  /// Optional scroll controller
  final ScrollController? scrollController;

  /// Whether to enable prefetching
  final bool enablePrefetch;

  /// Threshold for prefetching (0.0 to 1.0)
  final double prefetchThreshold;

  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.enablePrefetch || _isLoadingMore || !widget.hasMore) {
      return;
    }

    final scrollRatio = _scrollController.scrollRatio;
    if (scrollRatio >= widget.prefetchThreshold && widget.onLoadMore != null) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore!();
    } on Object catch (_) {
      // Error handling is done by parent
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && !widget.isLoading) {
      return const Center(
        child: Text('No items found'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemExtent: widget.itemExtent,
      itemCount: widget.items.length + _buildTrailingWidgetsCount(),
      itemBuilder: (context, index) {
        // Show items
        if (index < widget.items.length) {
          return RepaintBoundary(
            child: widget.itemBuilder(context, widget.items[index], index),
          );
        }

        // Show loading indicator
        if (index == widget.items.length &&
            (widget.isLoading || _isLoadingMore)) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show error
        if (index == widget.items.length && widget.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: widget.onRetry,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Show load more button
        if (index == widget.items.length &&
            widget.hasMore &&
            !widget.isLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _loadMore,
                child: const Text('Load More'),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  int _buildTrailingWidgetsCount() {
    if (widget.items.isEmpty) {
      return 0;
    }

    if (widget.isLoading || _isLoadingMore) {
      return 1;
    }

    if (widget.error != null) {
      return 1;
    }

    if (widget.hasMore) {
      return 1;
    }

    return 0;
  }
}
