# Issue 146 - acceptance evidence

`TaskModel` wrote offset-less local timestamps. Fixed in PR #159
(`cb0ab30`); this directory is the evidence for the five acceptance criteria.

## Artifacts

| File | What it is |
|---|---|
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `./scripts/test/run_acceptance.sh 146` - the same gates CI runs, plus the golden-tagged acceptance layer |
| `timestamp_probe.dart` | Prints the exact strings `toJson()` writes and what `fromJson()` reads back, per criterion. Runs under `flutter test`, not `dart run`, because `Task` reaches `package:flutter/foundation.dart` |
| `timestamp-probe-Asia-Bangkok.log` | Probe at UTC+07:00 |
| `timestamp-probe-America-New_York.log` | Probe at UTC-05:00 |
| `timestamp-probe-UTC.log` | Probe at UTC+00:00, the CI runner's zone |
| `task-model-tz-*.log` | `test/features/tasks/data/models/task_model_test.dart` under the same three zones |
| `goldens-checksums.txt` | See below |
| `*.png` | See below |

Reproduce the probe:

```bash
TZ=Asia/Bangkok flutter test docs/verification/issue-146/timestamp_probe.dart \
  --reporter expanded
```

## The PNGs prove nothing about this issue

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into the
evidence directory whether or not the issue is visual. This one is not: no
criterion here is about layout, and no screen in the tasks sample renders a
timestamp in these goldens.

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
