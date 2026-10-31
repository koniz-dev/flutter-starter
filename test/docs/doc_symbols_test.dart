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
//    still cites it - the direction the docs have actually drifted in,
//    where `contracts-map.md` named a provider that had never
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

  group('malformed directives', () {
    test('are reported with file and line; inline code and fences are not', () {
      final root = Directory.systemTemp.createTempSync('doc_symbols_bad_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('final fooProvider = 1;\n');
      File('${root.path}/docs/a.md')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          [
            '<!-- symbol: lib/a.dart fooProvider -->',
            '<!-- symbol: lib/nope.dart -->',
            '<!-- symbol: lib/nope.dart fooProvider extra -->',
            '<!-- symbol: lib/nope.dart fooProvider --> see above',
            '<!-- symbol: lib/nope.dart foo-provider -->',
            'Write a `<!-- symbol: <path> <name> -->` directive.',
            '```',
            '<!-- symbol: lib/nope.dart -->',
            '```',
            '',
          ].join('\n'),
        );

      final result = collectSymbolProblems(root);

      expect(result.directives, hasLength(1));
      expect(
        result.problems.map((p) => p.location),
        ['docs/a.md:2', 'docs/a.md:3', 'docs/a.md:4', 'docs/a.md:5'],
      );
      for (final problem in result.problems) {
        expect(problem.message, contains('malformed directive'));
      }
    });
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

    test('ignores a declaration inside a block comment or a string', () {
      expect(declaresSymbol('/*\nclass Ghost {}\n*/', 'Ghost'), isFalse);
      expect(
        declaresSymbol('/* outer /* inner */\nclass Ghost {}\n*/', 'Ghost'),
        isFalse,
      );
      expect(
        declaresSymbol(
          "const doc = '''\nfinal phantomProvider = 1;\n''';",
          'phantomProvider',
        ),
        isFalse,
      );
      expect(
        declaresSymbol('const s = "class Ghost {}";\nclass Real {}', 'Real'),
        isTrue,
      );
      expect(
        declaresSymbol("/* c */\nconst x = r'\\';\nclass After {}", 'After'),
        isTrue,
      );
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

  // A directive can name `Type.member`.
  group('declaresMember', () {
    final userModel = File(
      'lib/features/auth/data/models/user_model.dart',
    ).readAsStringSync();

    test('criterion 2: UserModel.fromJson and UserModel.toJson resolve', () {
      expect(declaresMember(userModel, 'UserModel', 'fromJson'), isTrue);
      expect(declaresMember(userModel, 'UserModel', 'toJson'), isTrue);
    });

    test('criterion 2: UserModel.toEntity does not', () {
      expect(declaresMember(userModel, 'UserModel', 'toEntity'), isFalse);
    });

    test('an initializer or expression body declares nothing', () {
      const source = '''
class Foo {
  Foo() : _a = _make() {}
  final int _a;
  final int y = helper(2);
  int get x => compute(1);
  static int _make() => 1;
  bool operator ==(Object other) => identical(this, other);
}
''';
      expect(declaresMember(source, 'Foo', 'helper'), isFalse);
      expect(declaresMember(source, 'Foo', 'compute'), isFalse);
      expect(declaresMember(source, 'Foo', 'identical'), isFalse);
      expect(declaresMember(source, 'Foo', 'y'), isTrue);
      expect(declaresMember(source, 'Foo', 'x'), isTrue);
      expect(declaresMember(source, 'Foo', '_a'), isTrue);
      expect(declaresMember(source, 'Foo', '_make'), isTrue);
    });

    test('reads each member form, at the type body top level only', () {
      const source = '''
class Box {
  Box(this.size);
  Box.empty() : size = 0;
  factory Box.of(int n) => Box(n);
  final int size;
  static const max = 9;
  int get area => size * size;
  set label(String v) {}
  void grow() {
    shrink();
  }
}
''';
      for (final member in const [
        'empty',
        'of',
        'size',
        'max',
        'area',
        'label',
        'grow',
      ]) {
        expect(declaresMember(source, 'Box', member), isTrue, reason: member);
      }
      expect(
        declaresMember(source, 'Box', 'shrink'),
        isFalse,
        reason: 'a call inside a method body is not a declaration',
      );
      expect(declaresMember(source, 'Crate', 'size'), isFalse);
    });
  });
}
