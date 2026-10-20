# Issue 188 - acceptance evidence

`CacheInterceptor` stored an offset-less local timestamp for cache age, so the
age was wrong by the UTC offset after a timezone change or a DST transition.

Fix merged as
[PR #219](https://github.com/koniz-dev/flutter-starter/pull/219), squash commit
`fb9c389`. Everything below was produced on `main` at `fb9c389` unless the file
says otherwise.

## What changed

- `lib/core/network/interceptors/cache_interceptor.dart` writes the timestamp
  with `DateFormatter.formatIso8601` and reads it with
  `DateFormatter.parseIso8601` - the **UTC** pair, not the wall-clock pair
  (`formatDateTime` / `parseDateTime`). Cache age is a duration between two
  instants; the wall-clock pair deliberately writes no marker saying which
  instant the digits name, which is the defect itself. `now` is taken as
  `DateTime.now().toUtc()` for symmetry.
- A timestamp that does not parse (or whose calendar date is out of range) no
  longer produces an age at all: the body, the timestamp and the index row are
  removed and the read is reported as a miss.
- `test/core/network/interceptors/cache_interceptor_timestamp_test.dart` - 12
  new tests.

## Criterion to artifact

| Criterion | Result | Artifact |
|---|---|---|
| 1. Stored timestamp ends with `Z` or a numeric offset, asserted from a test with a fake storage service | PASS | `criteria-1-4-tz-asia-bangkok.log`, group "criterion 1" (2 tests). The fake is `_InMemoryStorage implements StorageService` in the test file. |
| 2. An entry `N` minutes old ages as `N` minutes in either string form, under a non-UTC `TZ` | PASS | `criteria-1-4-tz-asia-bangkok.log` (`TZ=Asia/Bangkok`, host UTC offset `7:00:00` printed in every test name), group "criterion 2" (3 tests). Also run at `TZ=America/Santiago` (`-3:00:00`) and `TZ=UTC`. |
| 3. A `Z` entry is served before `maxAge`, evicted after `maxStale`, with no dependence on the host zone | PASS | Same three logs, group "criterion 3" (4 tests), which repeat the decision across six writer offsets from `-11:00` to `+13:00` and compute the age a reader seven hours away would get. |
| 4. An unparseable or out-of-range timestamp is a cache miss, not a nonsense age | PASS | Same three logs, group "criterion 4" (3 tests). |
| 5. `./scripts/dev/audit_template.sh` exits 0 | PASS | `criterion-5-audit_template.log`: format 0 changed, analyze "No issues found!", 2780 tests pass, `exit=0`. |

## Files

| File | What it is |
|---|---|
| `criteria-1-4-tz-asia-bangkok.log` | The new test file at `TZ=Asia/Bangkok`, expanded reporter. 12/12 pass. The host offset is in the group name, so the log itself records that the run was **not** in UTC. |
| `criteria-1-4-tz-america-santiago.log` | Same file at `TZ=America/Santiago` (offset `-3:00:00`), the other side of UTC. 12/12 pass. |
| `criteria-1-4-tz-utc.log` | Same file at `TZ=UTC` (offset `0:00:00`), the CI case. 12/12 pass. |
| `counterfactual.log` | The same test file run against the **pre-fix** interceptor (`fb9c389^`) at `TZ=Asia/Bangkok`. 5 of 12 fail, including the end-to-end cross-zone case, which reports `Duration:<7:00:00.000145>` as the age of an entry written seconds earlier. The header of the log carries the exact commands. |
| `criterion-5-audit_template.log` | `./scripts/dev/audit_template.sh`, trimmed head+tail by the same rule `scripts/test/run_acceptance.sh` uses. |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 188 --no-goldens`. |

## How the cross-zone case is actually driven

A Dart test process cannot change its own timezone once it has started, so the
differing offset is simulated on the other side of the round trip, which is
equivalent and portable:

- **Writer side.** A device at `hostOffset + 7h` writing instant `T` emits
  exactly the digits `T.add(7h).toIso8601String()` emits here. That is what
  `_offsetLessAtShiftedZone` builds, and it is what the pre-fix code would have
  written on that device.
- **Reader side.** `_ageComputedByReaderShiftedBy` takes the string the
  interceptor actually wrote and computes the age a reader `shift` away would
  get from it: a string with a designator parses to the same instant for
  everyone, a string without one lands `shift` away. Against the fix the answer
  is under 5 seconds for every shift tried; against pre-fix code it is
  `7:00:00`.

Both hold whatever the host zone is, which is why the same 12 tests pass at
`+07:00`, `-03:00` and UTC. A test that round-tripped in one zone would prove
nothing - that is exactly how this defect shipped.

## No goldens

Run with `--no-goldens`: nothing here renders. No PNG was produced and no
criterion rests on the repository's standing goldens.
