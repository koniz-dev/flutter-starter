// `flutter test --coverage` records only the libraries some test loads, so a
// file no test imported was missing from lcov.info and never lowered the
// total. tool/coverage_helper.dart writes a test importing every library
// under lib/; this checks that it really covers all of them.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the generated helper imports every library under lib/', () {
    final out = File(
      '${Directory.systemTemp.createTempSync('coverage_helper_').path}'
      '/helper_test.dart',
    );
    addTearDown(() => out.parent.deleteSync(recursive: true));

    final result = Process.runSync('dart', [
      'run',
      'tool/coverage_helper.dart',
      out.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final generated = out.readAsStringSync();
    final libraries = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where(
          (p) =>
              p.endsWith('.dart') &&
              !p.endsWith('.g.dart') &&
              !p.endsWith('.freezed.dart'),
        )
        .where(
          (p) => !File(p).readAsLinesSync().any((l) => l.startsWith('part of')),
        );

    final missing = [
      for (final path in libraries)
        // The quoted path only: `dart format` may wrap ` as lN` onto the
        // next line.
        if (!generated.contains("/${path.substring('lib/'.length)}'")) path,
    ];
    expect(missing, isEmpty);
    expect(generated, isNot(contains('.g.dart')));
  });
}
