# Issue 146 - acceptance evidence

`TaskModel` wrote offset-less local timestamps. Fixed in PR #159
(`cb0ab30`); this directory is the evidence for the five acceptance criteria.

## Artifacts

| File | What it is |
|---|---|
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `./scripts/test/run_acceptance.sh 146` - the same gates CI runs, plus the golden-tagged acceptance layer |
| `timestamp-probe-Asia-Bangkok.log` | The probe below at UTC+07:00 |
| `timestamp-probe-America-New_York.log` | The probe below at UTC-05:00 |
| `timestamp-probe-UTC.log` | The probe below at UTC+00:00, the CI runner's zone |
| `task-model-tz-*.log` | `test/features/tasks/data/models/task_model_test.dart` under the same three zones |
| `goldens-checksums.txt` | See "The PNGs prove nothing about this issue" |
| `*.png` | See "The PNGs prove nothing about this issue" |

## The probe

The three `timestamp-probe-*.log` files are the output of the source below,
which prints the exact strings `toJson()` writes and what `fromJson()` reads
back, one section per criterion. To reproduce, save it as
`test/features/tasks/timestamp_probe_test.dart` and run:

```bash
TZ=Asia/Bangkok flutter test test/features/tasks/timestamp_probe_test.dart \
  --reporter expanded
```

It is pasted here rather than committed as a `.dart` file on purpose. The
logs were captured from `docs/verification/issue-146/timestamp_probe.dart`,
but a committed Dart file in this directory is analyzed like any other source
(`analysis_options.yaml` does not exclude `docs/`), and this one imports
`package:flutter_starter/features/tasks/...`, which
`tool/strip_sample_features.dart` deletes. That broke the
`tasks-removed` and `both-samples-removed` strip variants with
`uri_does_not_exist`. `tool/strip_sample_features.dart` neither deletes nor
scans Dart files under `docs/`, so nothing warns about this before CI - filed
as its own issue.

It runs under `flutter test` rather than `dart run` because `Task` reaches
`package:flutter/foundation.dart`, which needs `dart:ui`. It uses
`stdout.writeln` rather than `print` because `very_good_analysis` bans the
latter.

```dart
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
```

## The PNGs prove nothing about this issue

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into the
evidence directory whether or not the issue is visual. This one is not: no
criterion here is about layout, and no screen in these goldens renders a task
timestamp.

All 13 copied PNGs are byte-identical to the repository's standing goldens -
`goldens-checksums.txt` pairs each `docs/verification/issue-146/<name>.png`
digest with `test/acceptance/goldens/<name>.png`. Three digests appear six
times rather than twice because three golden *names* share identical bytes
(`cold_start_no_session`, `cold_start_stale_user_no_token` and
`forced_logout_after` are one image; `cold_start_restored_session`,
`failed_logout_before_home` and `forced_logout_before` are another), so each
pair still matches. Regenerate with:

```bash
shasum -a 256 test/acceptance/goldens/*.png docs/verification/issue-146/*.png \
  | sort
```

## Decision on stored data: no migration

`fromJson` reads an offset-less legacy string as local wall clock, exactly as
`DateTime.parse` did, so nothing already on disk shifts. A migration through
the #60 framework was considered and rejected: a legacy string carries only
wall-clock digits, so converting it at first launch would still have to assume
the device's *current* zone - the same assumption the read path makes, at the
same moment - while adding a boot path that can fail (#101). Legacy rows drain
on their own, because `TasksLocalDataSource` rewrites the whole list on any
mutation. The full reasoning is in the `TaskModel` class doc.
