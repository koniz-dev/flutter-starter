# Performance Optimization Summary

## Overview

What this starter does for performance, split into two kinds:

- **Wired in** - runs in the app as shipped.
- **Building blocks** - tested utilities and widgets for your own screens. No
  screen in this starter calls them yet (see the "Exercised by a running
  screen?" column in [design decisions](../../architecture/design-decisions.md)),
  so they change nothing until you use them.

This page reports no before/after numbers. None were measured on this
starter, and a building block nothing calls cannot have improved anything.
Measure your own app with the steps under [Testing Performance](#testing-performance).

## Wired In

| What | Where |
|---|---|
| Environment config and image cache initialised in parallel at startup | `bootstrap()` in `lib/main.dart` |
| Image cache capped at 100 images / 100 MB | `_initializeImageCache()` in `lib/main.dart` |
| HTTP response caching for unauthenticated GETs | `CacheInterceptor`, installed by `ApiClient` |
| Optional HTTP timing traces | `PerformanceInterceptor`, when a performance service is wired |
| Build size report | `scripts/ci/build_all.sh --analyze-size` |

## Building Blocks (not called by any screen yet)

| Utility | Location |
|---|---|
| `OptimizedImage` | `lib/shared/widgets/optimized_image.dart` |
| `OptimizedListView` (pagination, prefetch) | `lib/shared/widgets/optimized_list_view.dart` |
| `PaginationHelper` | `lib/core/utils/pagination_helper.dart` |
| `Debouncer`, `Throttler` | `lib/core/utils/debouncer.dart` |
| `LazyLoader` (caching; deferred imports are yours to declare) | `lib/core/utils/lazy_loader.dart` |
| `ProviderDisposal` mixin (disposal bookkeeping; it does **not** touch the image cache) | `lib/core/utils/provider_disposal.dart` |
| `ImageCacheHelper`, `MemoryHelper` | `lib/core/utils/` |
| `IPerformanceService` and helpers | `lib/core/performance/` (see also `examples/performance_examples.dart`) |

<!-- symbol: lib/main.dart bootstrap -->

---

## Implementation Examples

### Using OptimizedImage

```dart
OptimizedImage(
  imageUrl: 'https://example.com/image.jpg',
  width: 200,
  height: 200,
  semanticLabel: 'Product photo', // omit only for decorative images
  placeholder: CircularProgressIndicator(),
  errorWidget: Icon(Icons.error),
  preload: true,
)
```

### Using OptimizedListView with Pagination

```dart
OptimizedListView<Item>(
  items: items,
  itemBuilder: (context, item, index) => ItemWidget(item),
  onLoadMore: () async {
    final moreItems = await loadMoreItems();
    return (moreItems, hasMore);
  },
  hasMore: hasMore,
  itemExtent: 80.0,
  enablePrefetch: true,
)
```

### Using PaginationHelper

```dart
final paginationHelper = PaginationHelper<Item>(
  config: const PaginationConfig(pageSize: 20),
  loadPage: (page) async {
    final response = await api.getItems(page: page, limit: 20);
    return (response.items, response.hasMore);
  },
);

await paginationHelper.loadNextPage();
```

### Using ProviderDisposal Mixin

```dart
class MyScreenState extends ConsumerState<MyScreen> with ProviderDisposal {
  @override
  void initState() {
    super.initState();
    final controller = TextEditingController();
    registerDisposable(() => controller.dispose());
  }
}
```

### Using Debouncer for Search

```dart
final debouncer = Debouncer(duration: Duration(milliseconds: 500));

TextField(
  onChanged: (value) {
    debouncer.run(() {
      performSearch(value);
    });
  },
)
```

### Using HTTP Caching

The cache interceptor is automatically integrated into `ApiClient`:

```dart
// Already configured in ApiClient
CacheInterceptor(
  storageService: storageService,
  cacheConfig: const CacheConfig(
    maxAge: Duration(hours: 1),
    maxStale: Duration(days: 7),
    enableCache: true,
  ),
)
```

### Using Image Cache

```dart
// Preload images
await ImageCacheHelper.preloadImage(imageUrl);

// Clear cache
ImageCacheHelper.clearCache();

// Get stats
final stats = ImageCacheHelper.getCacheStats();
```

### Using performance monitoring (`IPerformanceService`)

The app uses **`IPerformanceService`** (default: `NoOpPerformanceService`). Use **`PerformanceUtils`** helpers or `measureOperation` on a real implementation (see optional Firebase template under `lib/core/performance/infrastructure/`).

```dart
final data = await PerformanceUtils.measureApiCall(
  service: performanceService,
  method: 'GET',
  path: '/users',
  call: () => apiClient.get('/users'),
);
```

More patterns: [`examples/performance_examples.dart`](../../../examples/performance_examples.dart).

---

## Configuration

### Cache Configuration

The cache interceptor is automatically configured in `ApiClient`:

```dart
CacheInterceptor(
  storageService: storageService,
  cacheConfig: const CacheConfig(
    maxAge: Duration(hours: 1),
    maxStale: Duration(days: 7),
    enableCache: true,
  ),
)
```

### Image Cache Configuration

Configured in `main.dart`:

```dart
imageCache.maximumSize = 100; // Maximum number of images
imageCache.maximumSizeBytes = 100 << 20; // 100 MB
```

---

## Testing Performance

### Before Testing
1. Build in profile mode: `flutter build apk --profile` (release-like performance without a signing key; a release build needs one - see [Release signing](../../deployment/android-deployment.md#release-signing))
2. Disable debug mode
3. Test on real device (not emulator)

### Key Metrics to Monitor

1. **App Launch Time**
   ```bash
   adb shell am start -W -n com.example.flutter_starter/.MainActivity
   ```

2. **Memory Usage**
   ```bash
   adb shell dumpsys meminfo com.example.flutter_starter
   ```

3. **Frame Rate**
   ```bash
   flutter run --profile
   ```

4. **Build Size**
   ```bash
   ./scripts/ci/build_all.sh --analyze-size
   ```

---

## Best Practices

### DO
- Use `const` constructors for static widgets
- Dispose resources properly in widget lifecycle
- Cache network responses for GET requests
- Debounce search inputs to reduce API calls
- Use `OptimizedListView` for long lists
- Set image cache limits to prevent memory issues
- Monitor performance in debug mode
- Optimize assets before adding to project
- Remove unused dependencies regularly
- Use deferred imports (`import ... deferred as`) for large features

### DON'T
- Don't call `setState` during build
- Don't create widgets in build methods
- Don't use `ListView` for long lists (use `OptimizedListView`)
- Don't forget to dispose controllers
- Don't load all data at once (use pagination)
- Don't ignore memory warnings
- Don't use large images without optimization
- Don't make API calls on every keystroke
- Don't rebuild entire widgets when only part changes
- Don't ignore performance warnings

---

## Documentation

For detailed information, see:
- [Performance Optimization Guide](./optimization-guide.md) - Comprehensive guide with best practices
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices) - Official Flutter documentation

---

## Future Optimizations

1. **Service Workers**: For web platform
2. **Analytics Integration**: Track performance metrics in production
3. **Response Compression**: For API responses
4. **Advanced Prefetching**: For predicted user actions
5. **Image Format Detection**: Automatic WebP/AVIF support
6. **Background Sync**: For offline-first experience

---

## Related Documentation

- [Performance Optimization Guide](./optimization-guide.md) - Comprehensive optimization guide
- [API Documentation - Network](../../api/core/network.md) - Network utilities
- [API Documentation - Utils](../../api/core/utils.md) - Performance utilities
- [Common Tasks](../features/common-tasks.md) - Common development tasks

---

**Last Updated:** November 16, 2025

