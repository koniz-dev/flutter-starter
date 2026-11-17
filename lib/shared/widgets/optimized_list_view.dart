import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/localization/localization_extensions.dart';
import 'package:flutter_starter/core/utils/pagination_helper.dart'
    show PaginationScrollExtension;
import 'package:flutter_starter/shared/widgets/error_widget.dart';
import 'package:material_ui/material_ui.dart';

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
///   itemBuilder: (context, item, index) => ItemWidget(item),
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

  /// Initial items to display. Replacing their contents resets pagination.
  final List<T> items;

  /// Builder for each item
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Callback to load more items
  ///
  /// Returns the next page and whether another page exists. The widget appends
  /// the returned items and honours the returned hasMore value.
  final Future<(List<T>, bool)> Function()? onLoadMore;

  /// Initial pagination availability. Changing it resets pagination.
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
  late List<T> _items;
  late List<T> _inputItems;
  late bool _hasMore;
  int _generation = 0;

  /// Failure from the last prefetch, shown inline until a retry succeeds.
  ///
  /// Without this a failed prefetch only cleared the spinner, leaving a list
  /// that silently stopped growing.
  String? _loadMoreError;

  /// Whether [_scrollController] was created here, and so is disposed here.
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _items = List<T>.of(widget.items);
    _inputItems = List<T>.of(widget.items);
    _hasMore = widget.hasMore;
    _attach(widget.scrollController);
  }

  /// Adopts [external], or a controller of this state's own when null, and
  /// listens to it for prefetch.
  void _attach(ScrollController? external) {
    _ownsController = external == null;
    _scrollController = external ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  /// Stops listening to the current controller, disposing it if it was
  /// created here.
  void _detach() {
    if (_ownsController) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
  }

  @override
  void didUpdateWidget(OptimizedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_inputItems, widget.items) ||
        oldWidget.hasMore != widget.hasMore) {
      _items = List<T>.of(widget.items);
      _inputItems = List<T>.of(widget.items);
      _hasMore = widget.hasMore;
      _loadMoreError = null;
      _isLoadingMore = false;
      _generation++;
    }
    // A controller passed, removed or swapped after the first build: the list
    // used to keep the first one, so the parent's controller had no clients
    // and prefetch kept listening to the old one.
    if (widget.scrollController != oldWidget.scrollController) {
      _detach();
      _attach(widget.scrollController);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _onScroll() {
    // A failed prefetch waits for Retry (or new items): re-sending on every
    // scroll tick near the bottom flickered the error and hammered a failing
    // backend.
    if (!widget.enablePrefetch ||
        _isLoadingMore ||
        !_hasMore ||
        _loadMoreError != null) {
      return;
    }

    final scrollRatio = _scrollController.scrollRatio;
    if (scrollRatio >= widget.prefetchThreshold && widget.onLoadMore != null) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || widget.onLoadMore == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    final generation = _generation;
    try {
      final (items, hasMore) = await widget.onLoadMore!();
      if (mounted && generation == _generation) {
        setState(() {
          _items.addAll(items);
          _hasMore = hasMore;
        });
      }
    } on Object catch (error, stackTrace) {
      if (mounted && generation == _generation) {
        setState(() {
          _loadMoreError = error.toString();
        });
      }
      if (mounted && generation == _generation) {
        widget.onLoadMoreError?.call(error, stackTrace);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveError = widget.error ?? _loadMoreError;

    // An empty list that can still load is not "no items": it falls through
    // to the list, whose trailing slot offers Load More for the first page.
    // An error still takes the whole screen.
    final canLoadFirstPage = _hasMore && widget.onLoadMore != null;
    if (_items.isEmpty &&
        !widget.isLoading &&
        !_isLoadingMore &&
        (effectiveError != null || !canLoadFirstPage)) {
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

    if (widget.itemExtent == null) {
      return ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        itemCount: _items.length + _buildTrailingWidgetsCount(),
        itemBuilder: (context, index) => index < _items.length
            ? _item(context, index)
            : _trailing(context, effectiveError),
      );
    }
    // A fixed extent is for the items only: applied to the trailing slot too,
    // it squeezed the error message and its Retry button into one item's
    // height and overflowed.
    // ListView pads a null `padding` with the MediaQuery's vertical insets
    // (status bar, notch, home indicator) and removes them below it; a
    // CustomScrollView does neither, so do it here.
    final mediaQuery = MediaQuery.maybeOf(context);
    final padding =
        widget.padding ??
        mediaQuery?.padding.copyWith(left: 0, right: 0) ??
        EdgeInsets.zero;
    final list = CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverFixedExtentList(
                itemExtent: widget.itemExtent!,
                delegate: SliverChildBuilderDelegate(
                  _item,
                  childCount: _items.length,
                ),
              ),
              if (_buildTrailingWidgetsCount() > 0)
                SliverToBoxAdapter(child: _trailing(context, effectiveError)),
            ],
          ),
        ),
      ],
    );
    return widget.padding == null && mediaQuery != null
        ? MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: list,
          )
        : list;
  }

  Widget _item(BuildContext context, int index) =>
      RepaintBoundary(child: widget.itemBuilder(context, _items[index], index));

  /// The slot after the last item: a spinner, the error with its retry, or
  /// Load More.
  Widget _trailing(BuildContext context, String? effectiveError) {
    // Show loading indicator
    if (widget.isLoading || _isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error, including one raised by a failed prefetch
    if (effectiveError != null) {
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
    if (_hasMore && !widget.isLoading) {
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
  }

  /// The retry affordance to offer next to an error.
  ///
  /// Prefers the parent's [OptimizedListView.onRetry]; falls back to retrying
  /// the pagination callback itself, but only when that callback could
  /// actually do something (a button that no-ops is worse than no button).
  VoidCallback? get _effectiveOnRetry {
    final parentRetry = widget.onRetry;
    if (parentRetry != null) {
      // Clear a prefetch failure too, or prefetch, paused on it, never
      // resumed when the parent's retry produced the same items.
      return () {
        if (_loadMoreError != null) setState(() => _loadMoreError = null);
        parentRetry();
      };
    }
    if (widget.onLoadMore != null && _hasMore) {
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

    if (_hasMore) {
      return 1;
    }

    return 0;
  }
}
