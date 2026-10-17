// `mason make flutter_starter_setup` renames the Dart package, and README and
// `mason-demo-script.md` then document `mason make feature_clean`. The setup
// hook rewrote `package:flutter_starter/` in `lib/`, `test/`, the
// `create_feature` scripts and more - but never in `bricks/feature_clean/`,
// so every feature the brick generated after a rename imported a package that
// no longer existed (koniz-dev/flutter-starter#358).
//
// This drives the hook's own rewrite on a temporary copy of the brick, so the
// repository's templates are never touched.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../bricks/flutter_starter_setup/hooks/post_gen.dart' as hook;

const _old = 'package:flutter_starter/';

List<File> _files(Directory dir) =>
    dir.listSync(recursive: true).whereType<File>().toList();

void main() {
  late Directory root;
  late Directory brick;

  setUp(() {
    root = Directory.systemTemp.createTempSync('setup_brick_rename_');
    brick = Directory('${root.path}/bricks/feature_clean')
      ..createSync(recursive: true);
    for (final file in _files(Directory('bricks/feature_clean'))) {
      final relative = file.path.substring('bricks/feature_clean/'.length);
      File('${brick.path}/$relative')
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.readAsBytesSync());
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('the feature_clean templates import the template package today', () {
    // Guards the test against passing vacuously if the brick changes shape.
    final carrying = _files(
      brick,
    ).where((f) => f.readAsStringSync().contains(_old));
    expect(carrying, isNotEmpty);
  });

  test('criterion 1-2: the rewrite leaves no package:flutter_starter/ under '
      'bricks/feature_clean', () async {
    final before = _files(
      brick,
    ).where((f) => f.readAsStringSync().contains(_old)).length;

    final rewritten = await hook.rewriteFeatureBrickImports(
      root.path,
      'acme_shop',
    );

    expect(rewritten, before);
    final leftovers = [
      for (final f in _files(brick))
        if (f.readAsStringSync().contains(_old)) f.path,
    ];
    expect(leftovers, isEmpty);
    expect(
      _files(
        brick,
      ).where((f) => f.readAsStringSync().contains('package:acme_shop/')),
      hasLength(before),
    );
  });

  test('mustache tags and filenames survive the rewrite', () async {
    final names = _files(brick).map((f) => f.path).toSet();
    final tags = RegExp(r'\{\{[^}]+\}\}');
    final tagCount = _files(
      brick,
    ).map((f) => tags.allMatches(f.readAsStringSync()).length).fold(0, _sum);

    await hook.rewriteFeatureBrickImports(root.path, 'acme_shop');

    expect(_files(brick).map((f) => f.path).toSet(), names);
    expect(
      _files(
        brick,
      ).map((f) => tags.allMatches(f.readAsStringSync()).length).fold(0, _sum),
      tagCount,
    );
  });

  test('the setup hook calls the rewrite when it renames the package', () {
    final source = File(
      'bricks/flutter_starter_setup/hooks/post_gen.dart',
    ).readAsStringSync();
    final body = source.substring(
      source.indexOf('Future<void> _renameDartPackage('),
    );
    expect(
      body.substring(0, body.indexOf('\n}\n')),
      contains('rewriteFeatureBrickImports('),
    );
  });
}

int _sum(int a, int b) => a + b;
