# Performance Optimization

Performance optimization guides and documentation for the Flutter Starter app.

## Documentation

1. **[Summary](./summary.md)** - Quick reference guide with all optimizations and expected metrics
2. **[Optimization Guide](./optimization-guide.md)** - Comprehensive guide with detailed explanations, best practices, and examples

## Quick Start

New to performance optimization? Start here:

1. Read the [Summary](./summary.md) for an overview of all optimizations
2. Review the [Optimization Guide](./optimization-guide.md) for detailed information
3. Check the [API Documentation](../../api/core/utils.md) for utility classes
4. Optional runnable patterns: [`examples/performance_examples.dart`](../../../examples/performance_examples.dart) (not wired into `main.dart`)

## Key Topics

### App Launch Time
- Parallel initialization
- Image cache pre-configuration
- Lazy provider initialization

### Network Performance
- HTTP response caching
- Request debouncing
- Request throttling

### Memory Management
- Image cache management
- Memory leak detection
- Resource disposal patterns

### Build Size
- Dependency analysis
- Code splitting
- Asset optimization

### UI Performance
- Const constructors
- Performance monitoring
- Optimized list rendering

## Utilities

### Network
- `CacheInterceptor` - HTTP response caching
- `Debouncer` - Request debouncing
- `Throttler` - Request throttling

### Memory
- `ImageCacheHelper` - Image cache management
- `MemoryHelper` - Memory management utilities
- `DisposalTracker` - Automatic resource disposal

### Performance (in `lib/core/performance/`)
- `IPerformanceService` — contract; default `NoOpPerformanceService`, optional Firebase template under `infrastructure/`
- `performance_providers.dart` — Riverpod wiring
- Mixins / helpers — `PerformanceScreenMixin`, `performance_utils.dart`, etc.

## Related Documentation

- [API Documentation - Network](../../api/core/network.md) - Network utilities
- [API Documentation - Utils](../../api/core/utils.md) - Performance utilities
- [Common Tasks](../features/common-tasks.md) - Common development tasks
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices) - Official Flutter documentation

---

**Last updated:** Align with `lib/` when changing performance APIs.


