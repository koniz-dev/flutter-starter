# Issue 206 - a `symbol:` directive, so a doc cannot cite an identifier that does not exist

`docs/architecture/contracts-map.md` - the document an adopter follows to swap
an implementation - cited `tasksControllerProvider` and
`FirebaseFeatureFlagsRemoteDataSource`. Neither has ever existed anywhere in
this repository, and nothing caught it. #89 built the machinery for the strong
assertion (a documented constructor's parameter list matches its source); this
adds the weak, broad one.

Shipped in PR #238, merged as `6642748`.

## Evidence

| File | What it is |
|---|---|
| `criteria-1-4-symbol-check.log` | The clean tree, the three-way negative case, both gate directions, and all three strip variants |
| `criteria-5-6-directives-and-docs.log` | The ten directives in `contracts-map.md`, `check_docs.dart` green with them in place, and the `tool/README.md` section |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 206 --no-goldens` |

`--no-goldens`: a command-line checker, a test and two markdown files. Nothing
renders, there is no PNG in this directory, no criterion rests on a golden, and
the standing goldens under `test/acceptance/goldens/` were neither copied here
nor touched.

## Criterion 1 - the checker parses the directive and reports unresolved ones

PASS. `tool/doc_symbols.dart` walks every `.md` under `docs/` (skipping
`docs/verification/`, and skipping directives inside fenced code blocks), parses
`<!-- symbol: <path> <Identifier> -->`, and reports one problem per directive
whose identifier is not declared in the named file.

`criteria-1-4-symbol-check.log` section 2 shows all three failure shapes at
once - an identifier absent from a real file, a type absent from a real file,
and a path that does not exist:

```
docs/architecture/contracts-map.md:131: `tasksControllerProvider` is not declared in lib/core/di/providers.dart
docs/architecture/contracts-map.md:132: `FirebaseFeatureFlagsRemoteDataSource` is not declared in lib/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart
docs/architecture/contracts-map.md:133: source file not found -> lib/core/di/no_such_file.dart (directive names `apiClientProvider`)
```

The first two are the actual phantoms #182 found.

Declaration forms accepted, all unit-tested in
`test/docs/doc_symbols_test.dart` (`declaresSymbol accepts every declaration
form this repository uses`): `class` in every modifier spelling (`abstract`,
`abstract interface`, `final`, `sealed`, `mixin`), `mixin`, `base mixin`,
`enum`, `extension`, `extension type`, `typedef`, top-level
`final`/`const`/`var`/`late final` with or without an explicit type, and
top-level functions with or without a return type. The negative tests cover the
cases that matter: a name in a `//` or `///` comment, a name passed to
`ref.watch(...)`, and a longer identifier that merely contains the name
(`fooProvider` does not satisfy a directive for `foo`).

## Criterion 2 - wired into check_docs.dart, with its own summary line

PASS. `criteria-1-4-symbol-check.log` section 1:

```
$ dart run tool/check_docs.dart
links: checked 711 relative link(s) in 118 file(s); 0 broken
emoji: scanned 71 file(s); 0 line(s) with emoji
signatures: checked 5 documented constructor(s); 0 mismatched
symbols: checked 10 directive(s); 0 unresolved

OK: documentation checks passed.
exit: 0
```

and `dart run tool/check_docs.dart --symbols` runs it alone, also exit 0.
Section 2 is the same command on a broken tree: `3 problem(s) found.`,
`exit: 1`.

## Criterion 3 - a negative case, naming file and line

PASS, twice over. The run above is the end-to-end one. The unit form is
`test/docs/doc_symbols_test.dart`, `a directive naming a missing identifier
fails, with file and line`, which builds a throwaway tree and asserts the exact
strings:

```
docs/page.md:4: `phantomProvider` is not declared in lib/sample.dart
docs/page.md:5: source file not found -> lib/gone.dart (directive names `realProvider`)
```

Asserting the message, not just the count, is deliberate: a checker that fails
without saying which directive, in which file, on which line, costs more than
it saves. `collectSymbolProblems` exists so the test can reach the messages.

## Criterion 4 - which test fires on which side

PASS, both demonstrated in `criteria-1-4-symbol-check.log` section 3.

| Drift direction | Gate | Trigger |
|---|---|---|
| Identifier mistyped or invented **in a document** | `dart run tool/check_docs.dart` | **Docs check**, on a markdown diff. `.github/workflows/docs-check.yml` also lists `tool/doc_symbols.dart`, so editing the checker triggers it |
| Identifier deleted or renamed **in `lib/`**, document untouched | `test/docs/doc_symbols_test.dart` | **Quality gate**, under `flutter test`, on a `lib/` diff |

The code-side demonstration renames `raspServiceProvider` in
`lib/core/security/rasp_providers.dart` and touches no markdown at all:

```
Shell: docs/architecture/contracts-map.md:86: `raspServiceProvider` is not declared in lib/core/security/rasp_providers.dart
Shell: symbols: checked 10 directive(s); 1 unresolved
  Expected: <0>
    Actual: <1>
00:00 +7 -1: Some tests failed.
test exit: 1
```

`ci.yml` skips analyze and test on a markdown-only diff, so each gate sees
exactly one direction and neither is redundant - the same reasoning #89
recorded for `signature:`.

## Criterion 5 - contracts-map.md carries a directive for every provider, and is green

PASS. `criteria-5-6-directives-and-docs.log` lists all ten, at lines 78-87 of
the document:

`apiClientProvider`, `networkClientProvider`, `keyValueStoreProvider`,
`tokenStoreProvider`, `loggingServiceProvider`, `goRouterProvider`,
`authControllerProvider`, `authProvider`, `raspServiceProvider`,
`featureFlagsRemoteDataSourceProvider`.

Three of them resolve to a `.g.dart`, which is why the checker does not skip
generated output: `goRouterProvider`, `authProvider` and
`featureFlagsRemoteDataSourceProvider` are declared nowhere else.

**Writing the directives found a real error on the first run.**
`loggingServiceProvider` was written as `lib/core/di/providers.dart` and the
checker rejected it - it is declared in `lib/core/logging/logging_providers.dart`.
That is the failure mode this issue exists to catch, caught before the change
was even committed.

## Criterion 6 - tool/README.md documents the directive

PASS. `criteria-5-6-directives-and-docs.log` quotes the new
`### The `symbol:` directive` section, which sits directly under the
`signature:` bullet in the same list. It gives the syntax, the accepted
declaration forms, why generated output counts, why inline code spans are not
scanned, and the two exclusions (fenced blocks, `docs/verification/`). The
`--symbols` flag was added to the usage block next to `--signatures`.

## Beyond the criteria - keeping the strip variants green

`test/docs/doc_symbols_test.dart` runs under `flutter test`, which
`strip-smoke.yml` runs on every stripped tree. A directive naming
`lib/features/feature_flags/...` would therefore fail two of the three variants
once that feature is deleted. `strip_sample_features.dart` now drops any
`<!-- symbol: ... -->` line naming a path it removed - only the directive line,
never the prose - and says so on stdout.

`criteria-1-4-symbol-check.log` section 4 runs all three variants end to end:

| Variant | Strip output | `flutter test test/docs/` | directives left naming `lib/features/feature_flags` |
|---|---|---|---|
| `--apply` | `Dropped 1 symbol directive(s) ... from docs/architecture/contracts-map.md.` | All tests passed! | 0 |
| `--remove-tasks` | (nothing to drop) | All tests passed! | 1 |
| `--remove-feature-flags` | `Dropped 1 symbol directive(s) ...` | All tests passed! | 0 |

PR #238's own three Strip checks are the CI confirmation: green at 2m6s, 2m38s
and 2m37s.

## Also worth knowing

`docs/verification/` is excluded from the scan. An evidence file is a frozen
record of a past run; a directive in one would start failing the day the code it
described changed, which is the opposite of what evidence is for.

Inline code spans are deliberately **not** scanned, per the issue. The swap
map's cells mix identifiers, paths and prose, so a heuristic would either miss
the phantom or drown the author in false positives.
