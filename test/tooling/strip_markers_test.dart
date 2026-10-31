// The strip's markdown markers: every tag is validated before anything is
// deleted, and a strip removes only the tags it was asked to.
// Runs the tool in a scratch directory with
// `--keep-samples`, the one mode that touches nothing but markdown and the
// Mason bricks.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final tool = File('tool/strip_sample_features.dart').absolute.path;
  late Directory fixture;

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('strip_markers_');
    // The tool refuses to run anywhere but a project root.
    File('${fixture.path}/pubspec.yaml').writeAsStringSync('name: fixture\n');
    File('${fixture.path}/tool/strip_sample_features.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// placeholder\n');
  });
  tearDown(() => fixture.deleteSync(recursive: true));

  File doc(String body) => File('${fixture.path}/docs/a.md')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(body);

  ProcessResult strip({bool removeBricks = false}) => Process.runSync('dart', [
    'run',
    tool,
    '--apply',
    '--keep-samples',
    if (removeBricks) '--remove-bricks',
  ], workingDirectory: fixture.path);

  test('an unclosed sample marker aborts before anything is deleted', () {
    const body = '# Doc\n\n<!-- strip:tasks start -->\ntasks prose\n';
    final file = doc(body);

    final result = strip();

    expect(result.exitCode, 2, reason: '${result.stdout}${result.stderr}');
    expect(result.stderr, contains('tasks start marker is never closed'));
    expect(file.readAsStringSync(), body);
  });

  test('a sample end marker with no start aborts too', () {
    doc('# Doc\n\n<!-- strip:feature-flags end -->\n');

    final result = strip();

    expect(result.exitCode, 2);
    expect(result.stderr, contains('feature-flags end marker with no start'));
  });

  test('a line marker drops only its line, and only for a stripped tag', () {
    final file = doc('''
# Doc

| a | b |
| - | - |
| bricks row | x <!-- strip:bricks line --> |
| tasks row | y <!-- strip:tasks line --> |
| kept row | z |

<!-- strip:feature-flags start -->
flags prose
<!-- strip:feature-flags end -->
''');

    final result = strip(removeBricks: true);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final out = file.readAsStringSync();
    expect(out, isNot(contains('bricks row')));
    // --keep-samples keeps both samples, so their marked prose stays.
    expect(out, contains('tasks row'));
    expect(out, contains('flags prose'));
    expect(out, contains('kept row'));
  });

  group('--remove-bricks', () {
    const body = '''
# Doc

<!-- strip:bricks start -->
See [bricks](bricks/README.md).
<!-- strip:bricks end -->

| a | b |
| - | - |
| bricks row | [x](bricks/) <!-- strip:bricks line --> |
| kept row | z |
''';

    void seedBricks() {
      File('${fixture.path}/bricks/README.md')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('# Bricks\n');
      File('${fixture.path}/mason.yaml').writeAsStringSync('bricks:\n');
    }

    test('deletes bricks/ and mason.yaml, and the prose linking to them', () {
      seedBricks();
      final file = doc(body);

      final result = strip(removeBricks: true);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(Directory('${fixture.path}/bricks').existsSync(), isFalse);
      expect(File('${fixture.path}/mason.yaml').existsSync(), isFalse);
      final out = file.readAsStringSync();
      expect(out, isNot(contains('bricks')));
      expect(out, contains('kept row'));
    });

    test('without the flag, bricks and their prose stay', () {
      seedBricks();
      final file = doc(body);

      expect(strip().exitCode, 0);
      expect(Directory('${fixture.path}/bricks').existsSync(), isTrue);
      expect(File('${fixture.path}/mason.yaml').existsSync(), isTrue);
      expect(file.readAsStringSync(), body);
    });
  });
}
