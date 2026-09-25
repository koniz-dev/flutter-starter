// Regression tests for koniz-dev/flutter-starter#65, criterion 4.
import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/widgets/optimized_image.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _atDevicePixelRatio(double ratio, Widget child) {
  return MediaQuery(
    data: MediaQueryData(devicePixelRatio: ratio),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

ResizeImage _resizeProviderOf(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return image.image as ResizeImage;
}

void main() {
  group('OptimizedImage decode size', () {
    testWidgets('decodes at logical size * devicePixelRatio', (tester) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          3,
          const OptimizedImage(
            imageUrl: 'https://example.com/image.jpg',
            width: 100,
            height: 120,
          ),
        ),
      );

      final provider = _resizeProviderOf(tester);
      expect(provider.width, 300);
      expect(provider.height, 360);
    });

    testWidgets('a devicePixelRatio of 1 decodes at the logical size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          1,
          const OptimizedImage(
            imageUrl: 'https://example.com/image.jpg',
            width: 100,
            height: 120,
          ),
        ),
      );

      final provider = _resizeProviderOf(tester);
      expect(provider.width, 100);
      expect(provider.height, 120);
    });

    testWidgets('an unsized image is not resized', (tester) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          3,
          const OptimizedImage(imageUrl: 'https://example.com/image.jpg'),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isNot(isA<ResizeImage>()));
    });
  });

  group('OptimizedImage semantics', () {
    testWidgets('forwards semanticLabel and stays in the semantics tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          2,
          const OptimizedImage(
            imageUrl: 'https://example.com/image.jpg',
            semanticLabel: 'Profile photo',
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'Profile photo');
      expect(image.excludeFromSemantics, isFalse);
    });

    testWidgets('an unlabeled image is excluded rather than left unlabeled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          2,
          const OptimizedImage(imageUrl: 'https://example.com/image.jpg'),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, isNull);
      expect(image.excludeFromSemantics, isTrue);
    });
  });

  group('OptimizedImage preload', () {
    late List<String> preloaded;

    setUp(() {
      preloaded = <String>[];
      OptimizedImage.debugPreloader = (url, {context}) async {
        preloaded.add(url);
        return true;
      };
    });

    tearDown(() => OptimizedImage.debugPreloader = null);

    testWidgets('fires once per URL, not once per rebuild', (tester) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          2,
          const OptimizedImage(
            imageUrl: 'https://example.com/a.jpg',
            preload: true,
          ),
        ),
      );

      // Several rebuilds of the same widget configuration.
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(
          _atDevicePixelRatio(
            2,
            const OptimizedImage(
              imageUrl: 'https://example.com/a.jpg',
              preload: true,
            ),
          ),
        );
      }

      expect(preloaded, ['https://example.com/a.jpg']);
    });

    testWidgets('fires again when the URL changes', (tester) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          2,
          const OptimizedImage(
            imageUrl: 'https://example.com/a.jpg',
            preload: true,
          ),
        ),
      );
      await tester.pumpWidget(
        _atDevicePixelRatio(
          2,
          const OptimizedImage(
            imageUrl: 'https://example.com/b.jpg',
            preload: true,
          ),
        ),
      );

      expect(preloaded, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
    });

    testWidgets('does not fire when preload is false or the URL is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _atDevicePixelRatio(
          2,
          const OptimizedImage(imageUrl: 'https://example.com/a.jpg'),
        ),
      );
      await tester.pumpWidget(
        _atDevicePixelRatio(
          2,
          const OptimizedImage(imageUrl: '', preload: true),
        ),
      );

      expect(preloaded, isEmpty);
    });
  });
}
