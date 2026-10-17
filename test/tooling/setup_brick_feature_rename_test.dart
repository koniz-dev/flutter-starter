// `mason make flutter_starter_setup` renames the Dart package, and README and
// `mason-demo-script.md` then document `mason make feature_clean`. The setup
// hook rewrote `package:flutter_starter/` in `lib/`, `test/`, the
// `create_feature` scripts and more - but never in `bricks/feature_clean/`,
// so every feature the brick generated after a rename imported a package that
// no longer existed (koniz-dev/flutter-starter#358).
//
// This drives the hook's own rewrite on a temporary copy of the brick, so the
// repository's templates are never touched.
//
// The hook runs in a `dart` subprocess rather than being imported: an adopter
// may delete `bricks/` (the fork guide says so, and strip-smoke's process-only
// variant does), and a static import of a deleted file would turn
// `flutter analyze` red. The file skips when there is no brick, and when the
// setup brick has already renamed the package - that rename rewrites this
// file's own `package:` literals, so nothing is left to check.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _old = 'package:flutter_starter/';
const _hookPath = 'bricks/flutter_starter_setup/hooks/post_gen.dart';

String? _skipReason() {
  if (!File(_hookPath).existsSync() ||
      !Directory('bricks/feature_clean').existsSync()) {
    return 'bricks/ has been removed';
  }
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final named = RegExp(r'^name:\s*flutter_starter\s*$', multiLine: true);
  if (!named.hasMatch(pubspec)) {
    return 'the package has already been renamed by the setup brick';
  }
  return null;
}

/// Runs the hook's `rewriteFeatureBrickImports(root, packageName)` in a
/// subprocess and returns its result.
Future<int> _rewrite(String root, String packageName) async {
  final hook = File(_hookPath).absolute.uri;
  final script = File('$root/run_hook.dart')
    ..writeAsStringSync(
      "import '$hook' as hook;\n"
      'Future<void> main(List<String> args) async =>\n'
      '    print(await hook.rewriteFeatureBrickImports(args[0], args[1]));\n',
    );
  final packages = File('.dart_tool/package_config.json').absolute.path;
  final result = await Process.run('dart', [
    '--packages=$packages',
    script.path,
    root,
    packageName,
  ]);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  return int.parse((result.stdout as String).trim());
}

List<File> _files(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => !f.path.endsWith('run_hook.dart'))
    .toList();

int _sum(int a, int b) => a + b;

void main() {
  final skip = _skipReason();
  if (skip != null) {
    test('feature_clean brick rename', () {}, skip: skip);
    return;
  }

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

    final rewritten = await _rewrite(root.path, 'acme_shop');

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

    await _rewrite(root.path, 'acme_shop');

    expect(_files(brick).map((f) => f.path).toSet(), names);
    expect(
      _files(
        brick,
      ).map((f) => tags.allMatches(f.readAsStringSync()).length).fold(0, _sum),
      tagCount,
    );
  });

  test('the setup hook calls the rewrite when it renames the package', () {
    final source = File(_hookPath).readAsStringSync();
    final body = source.substring(
      source.indexOf('Future<void> _renameDartPackage('),
    );
    expect(
      body.substring(0, body.indexOf('\n}\n')),
      contains('rewriteFeatureBrickImports('),
    );
  });
}
