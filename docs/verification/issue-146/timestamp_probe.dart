// Evidence probe for koniz-dev/flutter-starter#146.
//
// Prints the exact strings `TaskModel.toJson()` writes and what
// `TaskModel.fromJson()` makes of them, so the acceptance criteria can be
// read off a log rather than inferred from a passing test name.
//
// Reproduce from the repository root:
//
//   TZ=Asia/Bangkok flutter test docs/verification/issue-146/timestamp_probe.dart \
//     --reporter expanded
//
// It runs under `flutter test` rather than `dart run` because `Task` reaches
// `package:flutter/foundation.dart`, which needs `dart:ui`. It is outside
// `test/`, so the Quality gate's `flutter test` never picks it up - but
// `flutter analyze` does analyze it, which is why it uses `stdout.writeln`
// rather than the `very_good_analysis`-banned `print`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_test/flutter_test.dart';

TaskModel _task(DateTime at) =>
    TaskModel(id: 'task-1', title: 'Probe', createdAt: at, updatedAt: at);

Map<String, dynamic> _row(String timestamp) => <String, dynamic>{
  'id': 'task-1',
  'title': 'Probe',
  'created_at': timestamp,
  'updated_at': timestamp,
};

void main() {
  test('timestamp probe', () {
    final zoneProbe = DateTime(2024, 1, 15, 14, 30, 45);
    stdout
      ..writeln(
        'host zone: ${zoneProbe.timeZoneName} '
        'offset ${zoneProbe.timeZoneOffset}',
      )
      ..writeln()
      // Criterion 1 - a designator is written for both kinds of DateTime.
      ..writeln('--- criterion 1: toJson writes a designator');
    for (final original in <DateTime>[
      DateTime(2024, 1, 15, 14, 30, 45),
      DateTime.utc(2024, 1, 15, 7, 30, 45),
    ]) {
      final encoded =
          jsonDecode(jsonEncode(_task(original).toJson()))
              as Map<String, dynamic>;
      final written = encoded['created_at'] as String;
      stdout.writeln(
        '  in:  $original (isUtc=${original.isUtc})\n'
        '  out: "$written"  endsWith Z: ${written.endsWith('Z')}',
      );
      expect(written.endsWith('Z'), isTrue);
    }

    // Criterion 2 - the instant survives the round trip in this zone.
    stdout
      ..writeln()
      ..writeln('--- criterion 2: round trip preserves the instant');
    for (final original in <DateTime>[
      DateTime(2024, 1, 15, 14, 30, 45),
      DateTime.utc(2024, 1, 15, 7, 30, 45),
      DateTime(2024, 6, 30, 23, 59, 59, 999),
    ]) {
      final restored = TaskModel.fromJson(_task(original).toJson()).createdAt;
      stdout.writeln(
        '  $original -> $restored  '
        'isAtSameMomentAs: ${restored.isAtSameMomentAs(original)}',
      );
      expect(restored.isAtSameMomentAs(original), isTrue);
    }

    // Criterion 3 - a legacy offset-less row reads unshifted, then gains a
    // designator the next time the list is written.
    stdout
      ..writeln()
      ..writeln('--- criterion 3: legacy offset-less row');
    const legacy = '2026-09-19T14:30:00.000';
    final restored = TaskModel.fromJson(_row(legacy)).createdAt;
    stdout
      ..writeln('  stored:   "$legacy"')
      ..writeln('  read as:  $restored (isUtc=${restored.isUtc})')
      ..writeln(
        '  equals DateTime(2026, 9, 19, 14, 30): '
        '${restored == DateTime(2026, 9, 19, 14, 30)}',
      )
      ..writeln(
        '  old DateTime.parse gave: ${DateTime.parse(legacy)} -> unshifted: '
        '${restored.isAtSameMomentAs(DateTime.parse(legacy))}',
      )
      ..writeln(
        '  rewritten on next write: '
        '"${TaskModel.fromJson(_row(legacy)).toJson()['created_at']}"',
      );
    expect(restored, DateTime(2026, 9, 19, 14, 30));

    // Criterion 4 - an out-of-range calendar date is rejected.
    stdout
      ..writeln()
      ..writeln('--- criterion 4: malformed calendar date');
    const malformed = '2024-02-30T00:00:00Z';
    stdout.writeln(
      '  DateTime.parse("$malformed") = ${DateTime.parse(malformed)}  '
      '<- the silent roll-over',
    );
    try {
      TaskModel.fromJson(_row(malformed));
      fail('TaskModel.fromJson accepted $malformed - criterion 4 fails');
    } on FormatException catch (e) {
      stdout.writeln(
        '  TaskModel.fromJson threw FormatException: ${e.message}',
      );
    }
  });
}
