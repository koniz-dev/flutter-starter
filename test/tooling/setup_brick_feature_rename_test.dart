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
// may delete `bricks/` (the fork guide says so, and strip-smoke's keep-samples
// variant does), and a static import of a deleted file would turn
// `flutter analyze` red. The file skips when there is no brick, and when the
// setup brick has already renamed the package - that rename rewrites this
// file's own `package:` literals, so nothing is left to check.
//
// The subprocess cold-compiles the hook and `package:mason`, which takes tens
// of seconds on a loaded machine, so it runs exactly once, in `setUpAll`, and
// every test inspects that one result (koniz-dev/flutter-starter#446). The
// file-level timeout covers that one cold compile.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _old = 'package:flutter_starter/';
const _new = 'package:acme_shop/';
const _hookPath = 'bricks/flutter_starter_setup/hooks/post_gen.dart';
final _tags = RegExp(r'\{\{[^}]+\}\}');

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

/// Files under [dir], keyed by their path relative to it.
Map<String, String> _contents(Directory dir) => {
  for (final f in dir.listSync(recursive: true).whereType<File>())
    f.path.substring(dir.path.length + 1): f.readAsStringSync(),
};

void main() {
  final skip = _skipReason();
  if (skip != null) {
    test('feature_clean brick rename', () {}, skip: skip);
    return;
  }

  late Directory root;
  late Map<String, String> before;
  late Map<String, String> after;
  late int rewritten;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('setup_brick_rename_');
    final source = Directory('bricks/feature_clean');
    before = _contents(source);
    final brick = Directory('${root.path}/bricks/feature_clean');
    before.forEach((relative, text) {
      File('${brick.path}/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    });

    final hook = File(_hookPath).absolute.uri;
    final script = File('${root.path}/run_hook.dart')
      ..writeAsStringSync(
        "import '$hook' as hook;\n"
        'Future<void> main(List<String> args) async =>\n'
        '    print(await hook.rewriteFeatureBrickImports(args[0], args[1]));\n',
      );
    final packages = File('.dart_tool/package_config.json').absolute.path;
    final result = await Process.run('dart', [
      '--packages=$packages',
      script.path,
      root.path,
      'acme_shop',
    ]);
    final stdout = (result.stdout as String).trim();
    final parsed = int.tryParse(stdout);
    if (result.exitCode != 0 || parsed == null) {
      fail(
        'hook subprocess failed: exit ${result.exitCode}\n'
        'stdout: $stdout\nstderr: ${result.stderr}',
      );
    }
    rewritten = parsed;
    after = _contents(brick);
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('the feature_clean templates import the template package today', () {
    // Guards the test against passing vacuously if the brick changes shape.
    expect(before.values.where((t) => t.contains(_old)), isNotEmpty);
  });

  test('criterion 1-2: the rewrite leaves no package:flutter_starter/ under '
      'bricks/feature_clean', () {
    final carrying = before.values.where((t) => t.contains(_old)).length;
    expect(rewritten, carrying);
    expect([
      for (final e in after.entries)
        if (e.value.contains(_old)) e.key,
    ], isEmpty);
    expect(after.values.where((t) => t.contains(_new)), hasLength(carrying));
  });

  test('mustache tags and filenames survive the rewrite', () {
    expect(after.keys.toSet(), before.keys.toSet());
    for (final relative in before.keys) {
      expect(
        _tags.allMatches(after[relative]!).length,
        _tags.allMatches(before[relative]!).length,
        reason: relative,
      );
    }
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
