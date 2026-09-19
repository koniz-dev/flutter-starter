import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/image_cache_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize Flutter binding for image cache access
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCacheHelper', () {
    // Reset image cache before each test
    setUp(ImageCacheHelper.clearCache);

    group('preloadImage', () {
      testWidgets('should return false for invalid URL', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));

        final result = await ImageCacheHelper.preloadImage('');

        expect(result, isFalse);
      });

      testWidgets('should return false for invalid URL format', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));

        final result = await ImageCacheHelper.preloadImage('not-a-url');

        expect(result, isFalse);
      });

      // Note: Testing actual network image loading requires network access
      // and may be flaky in CI. Without context, preload uses
      // ImageProvider.resolve.

      testWidgets('reports failure when given a context', (tester) async {
        // precacheImage swallows the failure through its onError callback,
        // so the context branch returned true for every failed preload
        // while the no-context branch correctly returned false.
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        final context = tester.element(find.byType(Scaffold));

        final withContext = await ImageCacheHelper.preloadImage(
          'https://example.invalid/missing.jpg',
          context: context,
          timeout: const Duration(seconds: 2),
        );
        final withoutContext = await ImageCacheHelper.preloadImage(
          'https://example.invalid/missing.jpg',
          timeout: const Duration(seconds: 2),
        );

        expect(withContext, isFalse);
        expect(
          withContext,
          withoutContext,
          reason: 'both branches must agree about a failed preload',
        );
      });

      test('exposes a default timeout', () {
        expect(ImageCacheHelper.defaultPreloadTimeout, isA<Duration>());
        expect(
          ImageCacheHelper.defaultPreloadTimeout,
          greaterThan(Duration.zero),
        );
      });
    });

    group('preloadImages', () {
      test('should return 0 for empty list', () async {
        final count = await ImageCacheHelper.preloadImages([]);

        expect(count, 0);
      });

      testWidgets('should handle multiple URLs', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));

        final urls = [
          'https://example.com/image1.jpg',
          'https://example.com/image2.jpg',
        ];

        final count = await ImageCacheHelper.preloadImages(urls);

        expect(count, greaterThanOrEqualTo(0));
        expect(count, lessThanOrEqualTo(urls.length));
      });
    });

    group('clearCache', () {
      test('should clear image cache', () {
        expect(ImageCacheHelper.clearCache, returnsNormally);
      });
    });

    group('maxCacheSize', () {
      test('should get and set max cache size', () {
        final originalSize = ImageCacheHelper.maxCacheSize;

        ImageCacheHelper.maxCacheSize = 200;
        expect(ImageCacheHelper.maxCacheSize, 200);

        // Restore original
        ImageCacheHelper.maxCacheSize = originalSize;
      });
    });

    group('maxCacheBytes', () {
      test('should get and set max cache bytes', () {
        final originalBytes = ImageCacheHelper.maxCacheBytes;

        ImageCacheHelper.maxCacheBytes = 200 << 20; // 200 MB
        expect(ImageCacheHelper.maxCacheBytes, 200 << 20);

        // Restore original
        ImageCacheHelper.maxCacheBytes = originalBytes;
      });
    });

    group('getCacheStats', () {
      test('should return cache statistics', () {
        final stats = ImageCacheHelper.getCacheStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['currentSize'], isA<int>());
        expect(stats['currentSizeBytes'], isA<int>());
        expect(stats['maximumSize'], isA<int>());
        expect(stats['maximumSizeBytes'], isA<int>());
      });
    });
  });
}
