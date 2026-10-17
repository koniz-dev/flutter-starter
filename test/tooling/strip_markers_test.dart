// The strip's markdown markers: every tag is validated before anything is
// deleted, and a strip removes only the tags it was asked to
// (koniz-dev/flutter-starter#409). Runs the tool in a scratch directory with
// `--process-only`, the one mode that touches nothing but markdown and the
// process-only paths, none of which exist there.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final tool = File('tool/strip_sample_features.dart').absolute.path;
  late Directory fixture;

  setUp(() => fixture = Directory.systemTemp.createTempSync('strip_markers_'));
  tearDown(() => fixture.deleteSync(recursive: true));

  File doc(String body) => File('${fixture.path}/docs/a.md')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(body);

  ProcessResult strip() => Process.runSync('dart', [
    'run',
    tool,
    '--apply',
    '--process-only',
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
| process row | x <!-- strip:process-only line --> |
| tasks row | y <!-- strip:tasks line --> |
| kept row | z |

<!-- strip:feature-flags start -->
flags prose
<!-- strip:feature-flags end -->
''');

    final result = strip();

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final out = file.readAsStringSync();
    expect(out, isNot(contains('process row')));
    // --process-only keeps both samples, so their marked prose stays.
    expect(out, contains('tasks row'));
    expect(out, contains('flags prose'));
    expect(out, contains('kept row'));
  });
}
