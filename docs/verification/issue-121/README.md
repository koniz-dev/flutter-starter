# Issue 121 - the 401 refresh-queue test synchronised on a 50ms sleep

Evidence for koniz-dev/flutter-starter#121.

Three independent sessions reported the same failure on three commits
(`d188c79`, `a81920e`, `cd56d01`), none of whose diffs touch this path:
`test/core/network/interceptors/auth_interceptor_refresh_queue_test.dart`, test
`three concurrent 401s with a failing refresh`, `refreshCalls`
**Expected: <1> Actual: <3>**.

The issue asked for a diagnosis first: is this **(a)** a test artifact, or
**(b)** a real hole in `AuthInterceptor`'s `_isRefreshing` single-flight guard?

## Verdict: (a). A test artifact. The production guard was never breached.

The decisive artifact is [`diagnosis-probe.log`](diagnosis-probe.log), produced
by [`diagnosis_probe_test.dart`](diagnosis_probe_test.dart). The probe removes
wall-clock time from the experiment: it rendezvous structurally on the transport
having served all three 401s, then grants a *fixed number of event-loop turns*
before releasing the held-open refresh, and reports what the guard did. Turns
are ordering, not duration - a loaded machine runs the same continuations in the
same order, just later in real time.

```
turns= -1 refreshCallsAtRelease=1 refreshCallsFinal=3 adapterHits=3 setAccessTokenCalls=0 errors=3
turns=  0 refreshCallsAtRelease=1 refreshCallsFinal=3 adapterHits=3 setAccessTokenCalls=0 errors=3
turns=  1 refreshCallsAtRelease=1 refreshCallsFinal=3 adapterHits=3 setAccessTokenCalls=0 errors=3
turns=  2 refreshCallsAtRelease=1 refreshCallsFinal=2 adapterHits=3 setAccessTokenCalls=0 errors=3
turns=  3 refreshCallsAtRelease=1 refreshCallsFinal=1 adapterHits=3 setAccessTokenCalls=0 errors=3
...
turns= 64 refreshCallsAtRelease=1 refreshCallsFinal=1 adapterHits=3 setAccessTokenCalls=0 errors=3
```

Three things in that table settle the question.

1. **The reported symptom is reproduced deterministically, with no clock
   involved.** At 0 or 1 turns the run ends with `refreshCalls == 3` - exactly
   the reported value - every single time. A 401 needs **3 event-loop turns** to
   travel from the transport into `AuthInterceptor.onError`. The 50ms sleep was
   a wall-clock proxy for those 3 turns. When the isolate is starved long enough
   that 50ms of wall clock elapses mid-chain, the 50ms timer becomes due before
   the remaining turns run, the refresh is released early, `_isRefreshing` is
   reset in the `finally`, and each late-arriving 401 then *legitimately* starts
   its own refresh. Three refreshes, one per request.

2. **`refreshCallsAtRelease` is 1 in every row, including the rows that end
   at 3.** While the first refresh was actually in flight, the guard never
   admitted a second one. Every extra refresh happens strictly *after* the first
   refresh has completed and the guard has correctly reopened. That is the
   difference between "the guard has a hole" and "the test closed the window
   early", and the column separates them cleanly.

3. **No token write ever raced.** `setAccessTokenCalls=0` across the failing
   rows, and the 200-trial stress in the same log (`10` concurrent 401s inside
   one held-open refresh window) reports
   `distinct refreshesAdmittedInWindow={1} distinct tokenWritesInWindow={0}`.
   The scenario the issue was raised to P1 for - "three refreshes against a real
   backend, two racing to write `_tokenStore.setAccessToken`" - does not occur.

Corroborating code reading, in
`lib/core/network/interceptors/auth_interceptor.dart` at `cd91303`
(`_handle401Error`): the `if (_isRefreshing)` test on line 276 and the
`_isRefreshing = true` assignment on line 281 are separated by no `await` and no
other suspension point, so in Dart's single-threaded event loop the check-and-set
is atomic. The only mutable state involved is the instance field on line 205;
the class's sole `static` member is
`static const List<String> _excludedEndpoints` (line 211). There is no
process-wide mutable state, and each test constructs its own interceptor, so
the cross-test-leakage hypothesis raised on #134 is also ruled out.

The `pkill -f flutter_test_listener` confound recorded on #109 is **not**
relevant here and no evidence of it was found: it produces `did not complete`,
whereas every sighting of this is a clean assertion failure with a wrong value,
which the probe reproduces from the sleep alone.

Since the production code is exonerated, **no issue was filed against
`epic:core-security`** and `lib/` is untouched by this change.

## The fix

`_CountingAuthInterceptor` in the test file replaces both sleeps with a
happens-before. It subclasses `AuthInterceptor`, counts entries into `onError`,
and completes a marker after `super.onError` returns. That is rigorous rather
than approximate: `super.onError` reaches the `_isRefreshing` guard and either
starts the refresh or queues the request *synchronously*, so when control
returns to the override the request is already parked. `await
interceptor.seen(3)` therefore means "the guard has processed all three 401s",
which is what the sleep was pretending to mean.

Both concurrency tests then assert `refreshCalls == 1` **while the refresh is
still in flight**, before releasing it. That assertion is the single-flight
property itself rather than a downstream consequence of it.

## Criterion map

| Criterion | Result | Artifact |
|---|---|---|
| 1. No wall-clock delay establishes ordering; the queued requests are *observed* to have reached the interceptor | PASS | [`auth_interceptor_refresh_queue_test.dart`](../../../test/core/network/interceptors/auth_interceptor_refresh_queue_test.dart) - `_CountingAuthInterceptor` / `await _within(interceptor.seen(3))`; both sleeps gone, see `grep-no-magic-delay.log` |
| 2. The succeeding-refresh sibling gets the same treatment | PASS | Same file, second test: identical `seen(3)` rendezvous plus a pre-release `retryAdapter.hits == 0` assertion |
| 3. The test still fails if the interceptor stops queueing | PASS | [`counterfactual-queueing-removed.log`](counterfactual-queueing-removed.log) - with `if (_isRefreshing) return _queueRequest(...)` commented out in `lib/`, **both** tests fail with `Expected: <1> Actual: <3>`, deterministically. The patch was reverted immediately; `lib/` is unchanged in this PR. |
| 4. 20 consecutive runs of the file pass, and `audit_template.sh` exits 0 | PASS | [`repeat-20x-under-load.log`](repeat-20x-under-load.log) (20/20 PASS under load averages 46-131 on a 6-CPU host) and [`audit-run1.log`](audit-run1.log), [`audit-run2.log`](audit-run2.log), [`audit-run3.log`](audit-run3.log) (3/3 exit 0, 2645 tests). On merged `main`: [`acceptance-refresh-queue-named.log`](acceptance-refresh-queue-named.log) (all six tests named, exit 0), [`format.log`](format.log), [`analyze.log`](analyze.log), [`tests.log`](tests.log) (2688 passed, 8 skipped, exit 0), [`goldens.log`](goldens.log) |
| 5. No `Future.delayed` with a magic millisecond constant remains as a synchronisation mechanism | PASS | [`grep-no-magic-delay.log`](grep-no-magic-delay.log) - the only surviving `Duration` in the file is the `_within` deadline, documented as a hang detector no assertion depends on |

## Extra: the flake caught in the act

[`old-vs-new-under-load.log`](old-vs-new-under-load.log) runs the pre-#121 file
(restored verbatim from `origin/main`) and the fixed file alternately on the
same machine under the same deliberate load, 15 rounds each. The old one failed
round 3 with the exact reported error at the exact reported line:

```
round  3  OLD=FAIL  NEW=PASS  (load 305.15)
--- OLD failure, round 3 ---
  Expected: <1>
    Actual: <3>
  test/core/network/interceptors/zz_old_sleep_version_test.dart 172:9
```

Final tally: `rounds: 15   OLD failures: 1   NEW failures: 0`. This is the
first time the flake has been reproduced on demand rather than stumbled into.

## Re-running the probe

`diagnosis_probe_test.dart` lives here rather than under `test/` so it does not
join the suite. To re-run it:

```bash
cp docs/verification/issue-121/diagnosis_probe_test.dart \
   test/core/network/interceptors/zz_probe_test.dart
flutter test test/core/network/interceptors/zz_probe_test.dart
rm test/core/network/interceptors/zz_probe_test.dart
```

## Acceptance harness

`./scripts/test/run_acceptance.sh 121` was run against merged `main` at
`cd91303`, which contains the fix (`7621ac5`, PR #165). All gates passed:
`format.log`, `analyze.log`, `tests.log` and `goldens.log` each end `exit: 0`.

`tests.log` uses `--reporter compact`, which overwrites its status line, so it
records counts (2688 passed, 8 skipped) but no test names.
`acceptance-refresh-queue-named.log` re-runs the changed file with
`--reporter expanded` on the same commit so all six tests are named
individually.

## Not evidence for this issue

This issue is not visual. `run_acceptance.sh` copies every standing golden PNG
under `test/acceptance/goldens/` into this directory; those screenshots are of
screens this change never touches and **no criterion above rests on them**.
All twelve were opened and inspected by the closing session anyway: they are
the login screen (with and without an error row), the home screen, the empty
and error list states, the startup-failure screen, and the light/dark text-style
sheets, every glyph an opaque Ahem block as expected. Nothing in them bears on a
test-synchronisation change.

`goldens-checksums.txt` proves the run left them byte-identical to the committed
goldens: all twelve copies match a `test/acceptance/goldens/*.png` hash exactly
(eight distinct images; four of the twelve are duplicates of another golden's
bytes, which is why the same hash appears more than once).
