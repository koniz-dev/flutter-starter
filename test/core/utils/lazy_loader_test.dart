import 'dart:async';
import 'package:flutter_starter/core/utils/lazy_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LazyLoader', () {
    test('should create instance with loader function', () {
      final loader = LazyLoader<String, int>(
        loader: (key) async => key.length,
      );

      expect(loader, isNotNull);
      expect(loader.cacheEnabled, isTrue);
      expect(loader.maxCacheSize, 50);
    });

    test('should create instance with custom config', () {
      final loader = LazyLoader<String, int>(
        loader: (key) async => key.length,
        cacheEnabled: false,
        maxCacheSize: 100,
      );

      expect(loader.cacheEnabled, isFalse);
      expect(loader.maxCacheSize, 100);
    });

    test('should load and cache value', () async {
      var loadCount = 0;
      final loader = LazyLoader<String, int>(
        loader: (key) async {
          loadCount++;
          return key.length;
        },
      );

      final result1 = await loader.load('test');
      expect(result1, 4);
      expect(loadCount, 1);

      final result2 = await loader.load('test');
      expect(result2, 4);
      expect(loadCount, 1); // Should use cache
    });

    test('should not cache when cacheEnabled is false', () async {
      var loadCount = 0;
      final loader = LazyLoader<String, int>(
        loader: (key) async {
          loadCount++;
          return key.length;
        },
        cacheEnabled: false,
      );

      await loader.load('test');
      await loader.load('test');
      expect(loadCount, 2); // Should load twice
    });

    test('should handle multiple concurrent loads', () async {
      var loadCount = 0;
      final loader = LazyLoader<String, int>(
        loader: (key) async {
          loadCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return key.length;
        },
      );

      final futures = [
        loader.load('test'),
        loader.load('test'),
        loader.load('test'),
      ];

      final results = await Future.wait(futures);
      expect(results, [4, 4, 4]);
      expect(loadCount, 1); // Should only load once
    });

    test('should evict oldest entries when cache is full', () async {
      final loader = LazyLoader<int, String>(
        loader: (key) async => 'value$key',
        maxCacheSize: 3,
      );

      await loader.load(1);
      await loader.load(2);
      await loader.load(3);
      expect(loader.cacheSize, 3);

      await loader.load(4);
      expect(loader.cacheSize, 3);
      expect(loader.isCached(1), isFalse); // Oldest should be evicted
      expect(loader.isCached(4), isTrue);
    });

    test('should preload resource', () async {
      var loadCount = 0;
      final loader = LazyLoader<String, int>(
        loader: (key) async {
          loadCount++;
          return key.length;
        },
      );

      loader.preload('test');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(loadCount, 1);
      expect(loader.isCached('test'), isTrue);
    });

    test('should preload multiple resources', () async {
      var loadCount = 0;
      final loader = LazyLoader<String, int>(
        loader: (key) async {
          loadCount++;
          return key.length;
        },
      );

      loader.preloadMultiple(['test1', 'test2', 'test3']);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(loadCount, 3);
    });

    test('should clear cache', () async {
      final loader = LazyLoader<String, int>(
        loader: (key) async => key.length,
      );

      await loader.load('test');
      expect(loader.cacheSize, 1);

      loader.clearCache();
      expect(loader.cacheSize, 0);
    });

    test('should evict specific key', () async {
      final loader = LazyLoader<String, int>(
        loader: (key) async => key.length,
      );

      await loader.load('test1');
      await loader.load('test2');
      expect(loader.cacheSize, 2);

      loader.evict('test1');
      expect(loader.isCached('test1'), isFalse);
      expect(loader.isCached('test2'), isTrue);
    });

    test('should check if key is cached', () async {
      final loader = LazyLoader<String, int>(
        loader: (key) async => key.length,
      );

      expect(loader.isCached('test'), isFalse);
      await loader.load('test');
      expect(loader.isCached('test'), isTrue);
    });

    test('should check if key is loading', () async {
      final completer = Completer<int>();
      final loader = LazyLoader<String, int>(
        loader: (key) => completer.future,
      );

      final loadFuture = loader.load('test');
      expect(loader.isLoading('test'), isTrue);

      completer.complete(42);
      await loadFuture;
      expect(loader.isLoading('test'), isFalse);
    });

    test('should handle load errors', () async {
      final loader = LazyLoader<String, int>(
        loader: (key) async {
          throw Exception('Load error');
        },
      );

      expect(
        () => loader.load('test'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DeferredImportLoader', () {
    test('should create instance with load function', () {
      final loader = DeferredImportLoader(
        loadFunction: () async {},
      );

      expect(loader, isNotNull);
      expect(loader.isLoaded, isFalse);
    });

    test('should load library', () async {
      var loadCount = 0;
      final loader = DeferredImportLoader(
        loadFunction: () async {
          loadCount++;
        },
      );

      await loader.load();
      expect(loadCount, 1);
      expect(loader.isLoaded, isTrue);
    });

    test('should not load twice', () async {
      var loadCount = 0;
      final loader = DeferredImportLoader(
        loadFunction: () async {
          loadCount++;
        },
      );

      await loader.load();
      await loader.load();
      expect(loadCount, 1);
    });

    test('should handle concurrent loads', () async {
      var loadCount = 0;
      final loader = DeferredImportLoader(
        loadFunction: () async {
          loadCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        },
      );

      await Future.wait([
        loader.load(),
        loader.load(),
        loader.load(),
      ]);

      expect(loadCount, 1);
    });

    test('should reset loader', () async {
      var loadCount = 0;
      final loader = DeferredImportLoader(
        loadFunction: () async {
          loadCount++;
        },
      );

      await loader.load();
      expect(loader.isLoaded, isTrue);

      loader.reset();
      expect(loader.isLoaded, isFalse);

      await loader.load();
      expect(loadCount, 2);
    });

    test('should handle load errors', () async {
      final loader = DeferredImportLoader(
        loadFunction: () async {
          throw Exception('Load error');
        },
      );

      expect(
        loader.load,
        throwsA(isA<Exception>()),
      );
      expect(loader.isLoaded, isFalse);
    });
  });

  group('LazyInitializer', () {
    test('should create instance with initializer', () {
      final initializer = LazyInitializer<int>(
        initializer: () async => 42,
      );

      expect(initializer, isNotNull);
      expect(initializer.isInitialized, isFalse);
    });

    test('should initialize and cache value', () async {
      var initCount = 0;
      final initializer = LazyInitializer<int>(
        initializer: () async {
          initCount++;
          return 42;
        },
      );

      final result1 = await initializer.get();
      expect(result1, 42);
      expect(initCount, 1);
      expect(initializer.isInitialized, isTrue);

      final result2 = await initializer.get();
      expect(result2, 42);
      expect(initCount, 1); // Should use cache
    });

    test('should handle concurrent initialization', () async {
      var initCount = 0;
      final initializer = LazyInitializer<int>(
        initializer: () async {
          initCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 42;
        },
      );

      final futures = [
        initializer.get(),
        initializer.get(),
        initializer.get(),
      ];

      final results = await Future.wait(futures);
      expect(results, [42, 42, 42]);
      expect(initCount, 1); // Should only initialize once
    });

    test('should reset initializer', () async {
      var initCount = 0;
      final initializer = LazyInitializer<int>(
        initializer: () async {
          initCount++;
          return 42;
        },
      );

      await initializer.get();
      expect(initializer.isInitialized, isTrue);

      initializer.reset();
      expect(initializer.isInitialized, isFalse);

      await initializer.get();
      expect(initCount, 2);
    });

    test('should handle initialization errors', () async {
      final initializer = LazyInitializer<int>(
        initializer: () async {
          throw Exception('Init error');
        },
      );

      expect(
        initializer.get,
        throwsA(isA<Exception>()),
      );
      expect(initializer.isInitialized, isFalse);
    });
  });
}

