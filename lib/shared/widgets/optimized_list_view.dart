import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/localization/localization_extensions.dart';
import 'package:flutter_starter/core/utils/pagination_helper.dart'
    show PaginationScrollExtension;
import 'package:flutter_starter/shared/widgets/error_widget.dart';

/// Optimized ListView with pagination support
///
/// This widget provides:
/// - Automatic pagination
/// - Prefetching support
/// - Performance optimizations
/// - Loading and error states, including failures raised by a prefetch: those
///   are shown inline (and reported through
///   [OptimizedListView.onLoadMoreError]) rather than silently clearing the
///   spinner
///
/// An empty list is only reported as "no items" when the load actually
/// succeeded. With a non-null [OptimizedListView.error] - or after a failed
/// prefetch - the widget renders the error plus a retry affordance instead.
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
    this.onLoadMoreError,
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

  /// Called when a prefetch triggered by scrolling throws
  ///
  /// The widget already shows the failure inline (see [OptimizedListView]'s
  /// class docs); this callback lets the parent react as well, for example by
  /// logging it or hoisting it into [error].
  final void Function(Object error, StackTrace stackTrace)? onLoadMoreError;

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

  /// Failure from the last prefetch, shown inline until a retry succeeds.
  ///
  /// Without this a failed prefetch only cleared the spinner, leaving a list
  /// that silently stopped growing.
  String? _loadMoreError;

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
      _loadMoreError = null;
    });

    try {
      await widget.onLoadMore!();
    } on Object catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _loadMoreError = error.toString();
        });
      }
      widget.onLoadMoreError?.call(error, stackTrace);
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
    final effectiveError = widget.error ?? _loadMoreError;

    if (widget.items.isEmpty && !widget.isLoading && !_isLoadingMore) {
      // "Failed, so there is nothing to show" and "loaded, genuinely empty"
      // must not render identically: an empty list with an error shows the
      // error and a retry affordance, never the empty state.
      if (effectiveError != null) {
        return AppErrorWidget(
          message: effectiveError,
          onRetry: _effectiveOnRetry,
        );
      }
      return Center(child: Text(context.l10n.noItemsFound));
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

        // Show error, including one raised by a failed prefetch
        if (index == widget.items.length && effectiveError != null) {
          final onRetry = _effectiveOnRetry;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    effectiveError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: onRetry,
                      child: Text(context.l10n.retry),
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
                child: Text(context.l10n.loadMore),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// The retry affordance to offer next to an error.
  ///
  /// Prefers the parent's [OptimizedListView.onRetry]; falls back to retrying
  /// the pagination callback itself, but only when that callback could
  /// actually do something (a button that no-ops is worse than no button).
  VoidCallback? get _effectiveOnRetry {
    if (widget.onRetry != null) {
      return widget.onRetry;
    }
    if (widget.onLoadMore != null && widget.hasMore) {
      return _retry;
    }
    return null;
  }

  /// Clears the last prefetch failure and tries again.
  void _retry() {
    setState(() {
      _loadMoreError = null;
    });
    unawaited(_loadMore());
  }

  int _buildTrailingWidgetsCount() {
    // Deliberately no `items.isEmpty -> 0` shortcut: that ran before the error
    // check and swallowed the error slot whenever the list was empty.
    if (widget.isLoading || _isLoadingMore) {
      return 1;
    }

    if (widget.error != null || _loadMoreError != null) {
      return 1;
    }

    if (widget.hasMore) {
      return 1;
    }

    return 0;
  }
}
