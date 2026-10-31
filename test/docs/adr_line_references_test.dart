// ADR 0005, then ADR 0006, cited `lib/...dart:<line>` references that rotted
// into blank lines and unrelated comments as the code moved. The ADRs name
// symbols instead, with `<!-- symbol: -->` directives that check_docs
// resolves.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no ADR cites a Dart file by line number', () {
    final adrs = Directory('docs/architecture/adr')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(adrs, isNotEmpty);

    final cited = [
      for (final adr in adrs)
        for (final (i, line) in adr.readAsLinesSync().indexed)
          if (RegExp(r'\.dart:\d+|`:\d+`').hasMatch(line))
            '${adr.path}:${i + 1}: $line',
    ];
    expect(cited, isEmpty, reason: cited.join('\n'));
  });
}
