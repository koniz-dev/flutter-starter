# Verification evidence - issue #109

test(logging): log_output_test.dart flakes with "did not complete" under a
full-suite run (consolidated with #145: network interceptor tests time out)

**Verdict: did not reproduce.** No code or test change was made. This directory
is the evidence behind closing the issue as an artifact of concurrent sessions,
which is the disposition the issue's own consolidation comment asked for as the
first step.

Verified on `main` at `4d8482a`, 2026-09-26. Host and toolchain in `env.txt`
(macOS 24.6.0 x86_64, Flutter 3.47.0 stable, Dart 3.13.0).

## Conditions - the confound was absent

The issue names two confounds from the day the symptom was observed: a session
working #53 ran `pkill -f flutter_test_listener`, a pattern that matches every
`flutter test` process on the machine and not only its own; and a #179 session
saw another worktree's output in its log through a shared Flutter tool cache.

Both required a second session. During this run there was **one** session on the
machine, **no** git worktrees (they were removed from this project), and every
command below ran **sequentially** - never two `flutter test` processes at once.
That is the "otherwise idle machine" the issue asked for.

## What was run

| Artifact | Command | Runs | Result |
|---|---|---|---|
| `log_output_20x.log` | `flutter test test/core/logging/log_output_test.dart --timeout=5m` | 20 consecutive | 20/20 `exit=0`, `+85: All tests passed!` every time |
| `interceptors_10x.log` | `flutter test test/core/network/interceptors/ --timeout=5m` | 10 consecutive | 10/10 `exit=0`, `+198: All tests passed!` every time |
| `audit_5x.log` | `./scripts/dev/audit_template.sh` | 5 consecutive | 5/5 `exit=0`, `+2812 ~8: All tests passed!` every time |
| `audit-tails.log` | last three lines of each of the five audit runs | - | the same summary line from each, independently of the one-line digest above |
| `log_output_run_20.log` | full output of the 20th `log_output_test.dart` run | - | kept whole so the pass is inspectable, not just counted |

Each audit run was additionally grepped for `did not complete`,
`Test timed out` and `TimeoutException`. All five returned **0 matches**; the
grep output is interleaved into `audit_5x.log` and is empty between the run
lines.

35 runs, 0 failures, 0 hangs.

## Why the proposed root cause is not just unreproduced but impossible

Criterion 1 assumes the 14 failing tests contended for a shared on-disk path.
They cannot: they never touch the disk.

`FileLogOutput._initializeLogFile` (`lib/core/logging/log_output.dart:116-128`)
calls `getApplicationDocumentsDirectory()` inside a `try`, and only sets
`_logDirectory` on success. In `flutter test`, that channel has no
implementation unless a test installs one. Only one group in
`test/core/logging/log_output_test.dart` does - `sink lifecycle (real temp
directory)` at `:1536`, which already creates a **per-test**
`Directory.systemTemp.createTemp('log_output_test')` in `setUp` and deletes it
in `tearDown`. The `FileLogOutput` and `FileLogOutput - Exception Handling
Coverage` groups, which contain all 14 tests the report names, install no
handler, so `_logDirectory` stays `null` and every later method short-circuits
on `if (_logDirectory == null) return` (`:241`, `:255`, `:310`, `:337`).

Probe run to confirm the channel really is unimplemented (written to
`test/zz_probe_109_test.dart`, run, and deleted - no `.dart` is committed under
`docs/verification/`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('probe: unmocked path_provider inside a flutter test', () async {
    Object? thrown;
    try {
      final d = await getApplicationDocumentsDirectory();
      print('PROBE: returned ${d.path}');
    } catch (e) {
      thrown = e;
      print('PROBE: threw ${e.runtimeType}: $e');
    }
    expect(thrown, isNotNull, reason: 'probe records the outcome, not a verdict');
  });
}
```

Output:

```
00:00 +0: probe: unmocked path_provider inside a flutter test
PROBE: threw MissingPluginException: MissingPluginException(No implementation
found for method getApplicationDocumentsDirectory on channel
plugins.flutter.io/path_provider)
00:00 +1: All tests passed!
```

So "shared on-disk state in that group" has no mechanism behind it, and the
isolation criterion 1 asks for is already in place in the one group that does
use the filesystem. `did not complete` with no assertion failure, on tests that
perform no I/O, is the signature of the **test runner process being killed**
from outside - exactly what `pkill -f flutter_test_listener` does.

## Criteria

| Criterion | Result | Evidence |
|---|---|---|
| 1. per-test temp directory isolation in `log_output_test.dart`, every `FileLogOutput` future awaited | **Not applicable** | The only group that touches the filesystem already has per-test `createTemp` isolation (`:1536-1556`); the groups that flaked touch no filesystem at all, per the probe above. There is no contention to isolate. |
| 2. `flutter test test/core/logging/log_output_test.dart --timeout=5m` passes 20 consecutive times; commit the loop output | **PASS** | `log_output_20x.log` - 20/20 `exit=0` |
| 3. `./scripts/dev/audit_template.sh` exits 0 on three consecutive runs; commit the exit codes | **PASS** (5 runs, not 3) | `audit_5x.log` and `audit-tails.log` - 5/5 `exit=0` |
| 4. if the root cause is in `lib/core/logging/log_output.dart`, fix it there rather than widening the timeout | **Not applicable** | No root cause was established in `lib/` or in `test/`. No timeout was widened and no production file was touched. |

The #145 half of this issue (network interceptor tests timing out) is covered by
`interceptors_10x.log`: 10/10 clean, plus the five full-suite audit runs that
include those 198 tests.

## What this evidence does not prove

It does not prove the original 14 `did not complete` lines never happened - they
are in #57's log. It proves that on a quiet machine, 35 runs later, the symptom
is absent and the mechanism criterion 1 proposes for it does not exist. If it
recurs while a second session is running, the process-kill explanation is the
one to check first, not a race in this test.
