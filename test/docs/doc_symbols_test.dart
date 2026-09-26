// Documentation-versus-code gate for asserted identifiers.
//
// `tool/doc_symbols.dart` checks that every `<!-- symbol: <path> <name> -->`
// directive under `docs/` names an identifier that is actually declared in
// that file. It runs from two triggers, and the split is the point:
//
//  * `dart run tool/check_docs.dart` is the **Docs check**, which fires on a
//    markdown diff. It catches a symbol mistyped or invented in a document.
//  * this test is the **Quality gate**, which fires on a `lib/` diff. It
//    catches an identifier deleted or renamed in `lib/` while the document
//    still cites it - the direction koniz-dev/flutter-starter#182 actually
//    drifted, where `contracts-map.md` named a provider that had never
//    existed.
//
// `ci.yml` skips analyze and test on a markdown-only diff, so each gate sees
// exactly one drift direction and neither is redundant.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_symbols.dart';

void main() {
  group('documented symbols', () {
    test('every <!-- symbol: --> directive resolves', () {
      expect(
        checkSymbols(Directory.current),
        0,
        reason:
            'A documented identifier is no longer declared where the '
            'directive says it is. Run `dart run tool/check_docs.dart '
            '--symbols` for the list, then fix the document or restore the '
            'identifier.',
      );
    });

    test('contracts-map.md still carries its directives', () {
      // Guards against the check passing because the directives were deleted.
      // The swap map is the document this machinery exists for.
      //
      // The bound is 9, not 10, because this test also runs in the stripped
      // trees `strip-smoke.yml` builds, and `strip_sample_features.dart`
      // removes the one directive that names a path under
      // `lib/features/feature_flags/`. Raise it in step with the file.
      final doc = File(
        'docs/architecture/contracts-map.md',
      ).readAsStringSync();
      expect(
        RegExp(r'<!--\s*symbol:').allMatches(doc).length,
        greaterThanOrEqualTo(9),
        reason:
            'contracts-map.md should keep a symbol directive for every '
            'provider identifier in its tables',
      );
    });

    test(
      'a directive naming a missing identifier fails, with file and line',
      () {
        final root = Directory.systemTemp.createTempSync('doc_symbols_');
        addTearDown(() => root.deleteSync(recursive: true));
        Directory('${root.path}/docs').createSync();
        Directory('${root.path}/lib').createSync();
        File('${root.path}/lib/sample.dart').writeAsStringSync('''
final realProvider = Provider<int>((ref) => 1);
''');
        File('${root.path}/docs/page.md').writeAsStringSync('''
# Page

<!-- symbol: lib/sample.dart realProvider -->
<!-- symbol: lib/sample.dart phantomProvider -->
<!-- symbol: lib/gone.dart realProvider -->
''');

        expect(checkSymbols(root, verbose: false), 2);

        final messages = collectSymbolProblems(
          root,
        ).problems.map((p) => p.toString()).toList();
        expect(messages, hasLength(2));
        expect(
          messages.first,
          'docs/page.md:4: `phantomProvider` is not declared in '
          'lib/sample.dart',
        );
        expect(
          messages.last,
          'docs/page.md:5: source file not found -> lib/gone.dart '
          '(directive names `realProvider`)',
        );
      },
    );

    test(
      'a directive inside a fenced block is documentation, not a directive',
      () {
        final root = Directory.systemTemp.createTempSync('doc_symbols_fence_');
        addTearDown(() => root.deleteSync(recursive: true));
        Directory('${root.path}/docs').createSync();
        File('${root.path}/docs/page.md').writeAsStringSync('''
# Page

```
<!-- symbol: lib/nowhere.dart neverDeclared -->
```
''');

        expect(checkSymbols(root, verbose: false), 0);
      },
    );
  });

  group('declaresSymbol', () {
    test('accepts every declaration form this repository uses', () {
      expect(declaresSymbol('class Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('abstract class Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('abstract interface class Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('final class Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('sealed class Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('mixin class Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('mixin Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('base mixin Foo {}', 'Foo'), isTrue);
      expect(declaresSymbol('enum Foo { a, b }', 'Foo'), isTrue);
      expect(declaresSymbol('extension Foo on int {}', 'Foo'), isTrue);
      expect(declaresSymbol('extension type Foo(int v) {}', 'Foo'), isTrue);
      expect(declaresSymbol('typedef Foo = void Function();', 'Foo'), isTrue);
      expect(declaresSymbol('final foo = 1;', 'foo'), isTrue);
      expect(declaresSymbol('const foo = Bar._();', 'foo'), isTrue);
      expect(declaresSymbol('var foo = 1;', 'foo'), isTrue);
      expect(declaresSymbol('late final Provider<int> foo;', 'foo'), isTrue);
      expect(
        declaresSymbol('final Provider<ApiClient> foo = Provider(...);', 'foo'),
        isTrue,
      );
      expect(declaresSymbol('void foo() {}', 'foo'), isTrue);
      expect(declaresSymbol('GoRouter foo(Ref ref) {\n}', 'foo'), isTrue);
      expect(declaresSymbol('List<int>? foo(int a) => null;', 'foo'), isTrue);
    });

    test('rejects a mention that is not a declaration', () {
      // The forms that produced the phantoms: a name that appears only in
      // prose, in a comment, or as a reference.
      expect(declaresSymbol('// final foo = 1;', 'foo'), isFalse);
      expect(
        declaresSymbol('/// Reads [foo] from the container.', 'foo'),
        isFalse,
      );
      expect(declaresSymbol('  ref.watch(foo);', 'foo'), isFalse);
      expect(declaresSymbol('final bar = ref.read(foo);', 'foo'), isFalse);
      expect(declaresSymbol('class Bar {}', 'Foo'), isFalse);
      expect(declaresSymbol('', 'foo'), isFalse);
    });

    test('does not match a longer identifier that contains the name', () {
      expect(declaresSymbol('final fooProvider = 1;', 'foo'), isFalse);
      expect(declaresSymbol('class FooBar {}', 'Foo'), isFalse);
    });

    test(
      'finds the real providers in this repository, including generated',
      () {
        String read(String path) => File(path).readAsStringSync();
        expect(
          declaresSymbol(
            read('lib/core/di/providers.dart'),
            'apiClientProvider',
          ),
          isTrue,
        );
        expect(
          declaresSymbol(
            read('lib/core/routing/app_router.g.dart'),
            'goRouterProvider',
          ),
          isTrue,
          reason:
              'generated output has to count - it is where this identifier '
              'is declared and nowhere else',
        );
        expect(
          declaresSymbol(
            read('lib/core/routing/app_router.dart'),
            'goRouter',
          ),
          isTrue,
          reason: 'the @riverpod-annotated top-level function form',
        );
      },
    );
  });
}
