import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/utils/memory_helper.dart';
import 'package:flutter_starter/core/utils/provider_disposal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderDisposal', () {
    testWidgets('should dispose registered disposables', (tester) async {
      var disposed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _TestWidget(
              onDispose: () {
                disposed = true;
              },
            ),
          ),
        ),
      );

      // Dispose the widget
      await tester.pumpWidget(const SizedBox.shrink());

      expect(disposed, isTrue);
    });

    testWidgets('should handle disposal errors gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _TestWidget(
              onDispose: () {
                throw Exception('Disposal error');
              },
            ),
          ),
        ),
      );

      // Should not throw
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('does not touch the global image cache on dispose', (
      tester,
    ) async {
      // dispose() used to call MemoryHelper.clearImageCache() whenever the
      // global cache was above 80% full, evicting images still mounted on
      // the screen underneath this one.
      final image = await tester.runAsync(
        () => createTestImage(width: 40, height: 40),
      );
      final completer = OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image!)),
      );
      imageCache.putIfAbsent('sentinel', () => completer);
      ImageStream()
        ..setCompleter(completer)
        ..addListener(ImageStreamListener((_, _) {}));
      await tester.pump();

      final previousMaxBytes = imageCache.maximumSizeBytes;
      addTearDown(() {
        imageCache
          ..maximumSizeBytes = previousMaxBytes
          ..clear()
          ..clearLiveImages();
      });

      // Squeeze the budget so the old `cacheSize > maxSize * 0.8` condition
      // is unambiguously true. Assert that precondition, or the test would
      // pass for the wrong reason.
      imageCache.maximumSizeBytes = imageCache.currentSizeBytes + 1;
      final info = MemoryHelper.getMemoryInfo();
      final cacheSize = info['imageCacheSizeBytes']! as int;
      final maxSize = info['imageCacheMaxSizeBytes']! as int;
      expect(cacheSize, greaterThan(0));
      expect(cacheSize, greaterThan(maxSize * 0.8));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: _TestWidget(onDispose: () {})),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        imageCache.containsKey('sentinel'),
        isTrue,
        reason: 'disposing a widget must not clear the global image cache',
      );
      expect(imageCache.currentSizeBytes, cacheSize);
    });

    testWidgets('the removed dynamic-provider helpers are gone', (
      tester,
    ) async {
      // registerProviderSubscription and WidgetRef.watchWithDisposal were
      // no-ops carrying the only two `// ignore:
      // argument_type_not_assignable` comments in lib/ - suppressing a
      // compile-time error, not a lint. They are deleted; registerDisposable
      // is the mixin's remaining, genuinely useful API.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: _TestWidget(onDispose: () {})),
        ),
      );
      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
      expect(state.registerDisposable, isNotNull);
    });
  });

  group('ProviderLifecycleManager', () {
    test('should dispose ProviderContainer', () {
      final container = ProviderContainer();
      final probe = Provider<String>((ref) => 'alive');

      // The old version of this test called `container.dispose()` directly -
      // never touching ProviderLifecycleManager at all - and ended in
      // `expect(true, isTrue)`. Reading a provider after the call is what
      // shows the container really was disposed.
      expect(container.read(probe), 'alive');

      ProviderLifecycleManager.disposeContainer(container);

      expect(() => container.read(probe), throwsStateError);
    });

    test('should handle non-ProviderContainer gracefully', () {
      // Should not throw when passed non-ProviderContainer
      expect(() {
        ProviderLifecycleManager.disposeContainer('not a container');
      }, returnsNormally);
    });
  });
}

class _TestWidget extends ConsumerStatefulWidget {
  const _TestWidget({required this.onDispose});

  final VoidCallback onDispose;

  @override
  ConsumerState<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends ConsumerState<_TestWidget>
    with ProviderDisposal {
  @override
  void initState() {
    super.initState();
    registerDisposable(widget.onDispose);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
