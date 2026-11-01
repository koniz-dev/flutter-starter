// Mason requires one file under the setup brick's __brick__/, so it writes
// _mason_hook_only.md into the project; the post_gen hook deletes it when
// setup finishes. This runs the hook's removeHookPlaceholder on a scratch
// directory.
//
// As in setup_brick_display_name_test.dart, the hook runs in a `dart`
// subprocess so that deleting bricks/ does not break analysis, and the file
// skips when there is no brick.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _brick = 'bricks/flutter_starter_setup';
const _placeholder = '_mason_hook_only.md';

/// Runs removeHookPlaceholder over [root].
Future<void> _removeIn(Directory root) async {
  final hook = File('$_brick/hooks/post_gen.dart').absolute.uri;
  // Outside [root], so the directory under test holds only the placeholder.
  final scripts = Directory.systemTemp.createTempSync('placeholder_hook_');
  final script = File('${scripts.path}/run_hook.dart')
    ..writeAsStringSync(
      "import 'package:mason/mason.dart';\n"
      "import '$hook' as hook;\n"
      'Future<void> main(List<String> args) =>\n'
      '    hook.removeHookPlaceholder(args[0], Logger());\n',
    );
  final packages = File('.dart_tool/package_config.json').absolute.path;
  final result = await Process.run('dart', [
    '--packages=$packages',
    script.path,
    root.path,
  ]);
  scripts.deleteSync(recursive: true);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}

void main() {
  final skip = File('$_brick/hooks/post_gen.dart').existsSync()
      ? null
      : 'bricks/ has been removed';

  late Directory root;
  setUp(() {
    if (skip == null) {
      root = Directory.systemTemp.createTempSync('setup_brick_placeholder_');
    }
  });
  tearDown(() {
    if (skip == null) root.deleteSync(recursive: true);
  });

  test('the placeholder the brick writes is deleted', () async {
    File('$_brick/__brick__/$_placeholder').copySync(
      '${root.path}/$_placeholder',
    );

    await _removeIn(root);

    expect(File('${root.path}/$_placeholder').existsSync(), isFalse);
  }, skip: skip);

  test('a file of the same name the brick did not write is kept', () async {
    final own = File('${root.path}/$_placeholder')
      ..writeAsStringSync('# My notes\n');

    await _removeIn(root);

    expect(own.readAsStringSync(), '# My notes\n');
  }, skip: skip);
}
