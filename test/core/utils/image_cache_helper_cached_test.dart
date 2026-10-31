// For an image already in the cache, ImageStream.addListener calls the
// listener synchronously. preloadImage without a context added it inside the
// cascade that assigned `stream`, so the listener's removeListener threw
// LateInitializationError, the completer never completed, and the call
// reported failure only after the whole timeout.

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/image_cache_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preloading an image already in the cache succeeds at once', (
    tester,
  ) async {
    const url = 'https://example.com/cached.png';
    final image = await tester.runAsync(createTestImage);
    imageCache.putIfAbsent(
      const NetworkImage(url),
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: image!)),
      ),
    );
    await tester.pump();
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final stopwatch = Stopwatch()..start();
    final result = await tester.runAsync(
      () => ImageCacheHelper.preloadImage(
        url,
        timeout: const Duration(seconds: 2),
      ),
    );
    stopwatch.stop();

    expect(result, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(errors, isEmpty, reason: errors.map((e) => '${e.exception}').join());
    imageCache.clear();
    // A regression hung here rather than failing; fail it in bounded time.
  }, timeout: const Timeout(Duration(seconds: 20)));
}
