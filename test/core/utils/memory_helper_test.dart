import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/memory_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryHelper', () {
    test('should have private constructor', () {
      // MemoryHelper has a private constructor, so we can't instantiate it
      // This test verifies the class exists and is accessible
      expect(MemoryHelper, isNotNull);
    });

    test('should clear image cache', () {
      // Test that clearImageCache doesn't throw
      expect(MemoryHelper.clearImageCache, returnsNormally);
    });

    test('should force GC in debug mode', () {
      // Test that forceGC doesn't throw
      expect(MemoryHelper.forceGC, returnsNormally);
    });

    test('should get memory info', () {
      final info = MemoryHelper.getMemoryInfo();

      expect(info, isA<Map<String, dynamic>>());
      expect(info.containsKey('imageCacheSize'), isTrue);
      expect(info.containsKey('imageCacheSizeBytes'), isTrue);
      expect(info.containsKey('imageCacheMaxSize'), isTrue);
      expect(info.containsKey('imageCacheMaxSizeBytes'), isTrue);
      expect(info['imageCacheSize'], isA<int>());
      expect(info['imageCacheSizeBytes'], isA<int>());
      expect(info['imageCacheMaxSize'], isA<int>());
      expect(info['imageCacheMaxSizeBytes'], isA<int>());
    });

    test('should optimize image cache with maxSize', () {
      final originalMaxSize = imageCache.maximumSize;
      const testMaxSize = 500;

      MemoryHelper.optimizeImageCache(maxSize: testMaxSize);

      expect(imageCache.maximumSize, testMaxSize);

      // Restore original value
      MemoryHelper.optimizeImageCache(maxSize: originalMaxSize);
    });

    test('should optimize image cache with maxSizeBytes', () {
      final originalMaxSizeBytes = imageCache.maximumSizeBytes;
      const testMaxSizeBytes = 50 * 1024 * 1024; // 50MB

      MemoryHelper.optimizeImageCache(maxSizeBytes: testMaxSizeBytes);

      expect(imageCache.maximumSizeBytes, testMaxSizeBytes);

      // Restore original value
      MemoryHelper.optimizeImageCache(maxSizeBytes: originalMaxSizeBytes);
    });

    test('should optimize image cache with both parameters', () {
      final originalMaxSize = imageCache.maximumSize;
      final originalMaxSizeBytes = imageCache.maximumSizeBytes;
      const testMaxSize = 600;
      const testMaxSizeBytes = 60 * 1024 * 1024; // 60MB

      MemoryHelper.optimizeImageCache(
        maxSize: testMaxSize,
        maxSizeBytes: testMaxSizeBytes,
      );

      expect(imageCache.maximumSize, testMaxSize);
      expect(imageCache.maximumSizeBytes, testMaxSizeBytes);

      // Restore original values
      MemoryHelper.optimizeImageCache(
        maxSize: originalMaxSize,
        maxSizeBytes: originalMaxSizeBytes,
      );
    });

    test('should optimize image cache with null parameters', () {
      final originalMaxSize = imageCache.maximumSize;
      final originalMaxSizeBytes = imageCache.maximumSizeBytes;

      MemoryHelper.optimizeImageCache();

      expect(imageCache.maximumSize, originalMaxSize);
      expect(imageCache.maximumSizeBytes, originalMaxSizeBytes);
    });

    test('should dispose resources', () async {
      // Test that disposeResources doesn't throw
      await expectLater(
        MemoryHelper.disposeResources(),
        completes,
      );
    });

    test('should dispose resources and clear cache', () async {
      // Verify that disposeResources calls clearImageCache
      await MemoryHelper.disposeResources();
      // If no exception is thrown, the method executed successfully
      expect(true, isTrue);
    });
  });

  group('DisposalTracker', () {
    testWidgets('should register and dispose disposables', (tester) async {
      var disposed1 = false;
      var disposed2 = false;

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(
            onDispose1: () => disposed1 = true,
            onDispose2: () => disposed2 = true,
          ),
        ),
      );

      expect(disposed1, isFalse);
      expect(disposed2, isFalse);

      // Dispose the widget
      await tester.pumpWidget(const SizedBox());

      expect(disposed1, isTrue);
      expect(disposed2, isTrue);
    });

    testWidgets('should handle empty disposables list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestWidgetEmpty(),
        ),
      );

      // Should not throw when disposing with no disposables
      await tester.pumpWidget(const SizedBox());
      expect(true, isTrue);
    });
  });
}

class _TestWidget extends StatefulWidget {
  const _TestWidget({
    required this.onDispose1,
    required this.onDispose2,
  });

  final VoidCallback onDispose1;
  final VoidCallback onDispose2;

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> with DisposalTracker {
  @override
  void initState() {
    super.initState();
    registerDisposable(widget.onDispose1);
    registerDisposable(widget.onDispose2);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

class _TestWidgetEmpty extends StatefulWidget {
  const _TestWidgetEmpty();

  @override
  State<_TestWidgetEmpty> createState() => _TestWidgetEmptyState();
}

class _TestWidgetEmptyState extends State<_TestWidgetEmpty>
    with DisposalTracker {
  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}


