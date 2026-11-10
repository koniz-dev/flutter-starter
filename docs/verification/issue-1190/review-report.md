# Independent pre-merge review: issue 1190 / PR 1201

Reviewed base c7de7052606 through head cbbae93d5f2f154964e923bea1e8092d2e593ddf. Read actual GitHub issue acceptance criteria, CLAUDE.md, maintainer process, full diff, storage contract, token-store adapter, repository logout implementation, and signOutProvider wiring. No tracked files or GitHub state changed.

## Introduced findings

1. P2: comments in storage arguments bypass the guard. At test/docs/session_token_examples_test.dart:166 the key is parsed from the original source, even though the lexer already knows comments are non-code. `secureStorage.remove(/* session key */ 'token');` returns zero violations. This is an ordinary annotated example of precisely the forbidden raw session-key delete. Parse the first argument from non-comment lexemes (preserving literal contents), and add this regression case.
2. P2: comments in log arguments falsely fail safe documentation. At test/docs/session_token_examples_test.dart:153, `_printsToken` removes strings but leaves comments. `print('Done' /* token */);` produces `token value passed to print`, although the only logged value is `Done`. Nested block comments also produce false positives: `/* /* nested */ secureStorage.remove('token'); */` flags a completely commented operation. Respect comment boundaries consistently before classifying arguments.

## Additional guard limitations (scope judgment)

These are reproducible omissions in the newly introduced heuristic, recorded separately from the above common-comment defects. The test explicitly disclaims whole-program type inference, so arbitrary aliasing is not demanded:

- `(secureStorage).remove('token');` is missed, despite requiring no type inference.
- `logger!.info(accessToken);` is missed; `LoggingService audit; audit.info(accessToken);` is also missed.
- A CommonMark blockquote fence (`> ```dart`, `> print(token);`, `> ```` closing with three backticks) extracts no Dart. Existing FenceTracker does not model blockquote containers, so this aspect is inherited from the shared helper rather than introduced there.
- Inline code within Dart-doc prose (`/// Example: `print(token)``) is discarded. Fenced Dart-doc examples are covered correctly.

## Checks

- `flutter test test/docs/session_token_examples_test.dart`: all 40 tests passed; raw log `1190-followup-focused-test.log`.
- Durable direct probes copied the actual guard helpers at this head: `1190-followup-probes.dart`, raw results `1190-followup-probes.log`.
- Extracted exact changed SessionManager blueprint with minimal contract fakes: null credential skips logout; nonnull credential, Exception, and Error each call logout once. All assertions passed. Source `1190-followup-session-manager.dart`, raw log `1190-followup-session-manager.log`.
- String literals containing `print(token)`, raw strings, escaped interpolation, normal/triple interpolation, provider/constructor storage usage, four-backtick fences, and nested Dart-doc fences were checked. The corrected previously reported cases remain covered by the passing focused suite.
- API doc additions align with ITokenStore, AuthRepository.logout, and signOutProvider signatures. The repository catches both Error and Exception during credential reads and still attempts teardown. No introduced API-doc or SessionManager read-error semantic defect found.

## Pre-existing concerns

No independently confirmed pre-existing runtime defect identified in this review. The shared fence helper's lack of blockquote parsing is described above as a scanner coverage limitation, not a runtime regression.

# Corrected-head follow-up: f64128fed697df184859ba756604e134066527be

Re-read combined base-to-head diff and actual updated guard. All previously reported comment-boundary failures and additional receiver/Markdown limitations are fixed. Re-ran the original independent probes against copied helpers from this actual head; expected unsafe cases now flag, safe comments/raw strings remain allowed, and blockquotes/Dart-doc inline examples are checked.

- Focused guard + CI markdown scope suite: 50 tests passed.
- `dart analyze test/docs/session_token_examples_test.dart`: no issues found.
- Verified full lockfile against base: only analyzer's dependency classification changed from transitive to direct dev. No dependency version or archive hash changed. Stored publisher proof names tools.dart.dev and hash matches lock.
- Scanner's internal import compiles/runs at the already locked analyzer 14.6.0; public FeatureSet and Token APIs used correctly in current code. No introduced dependency/API runtime regression identified. Future internal API changes will surface in test compilation when analyzer updates.
- API docs and SessionManager are unchanged from the earlier reviewed revision; prior exact extracted blueprint probe passed Exception/Error read semantics.

No outstanding actionable findings at corrected head. Raw final checks are `1190-followup-final.log`; independent copied-helper source and output are `1190-followup-final-probes.dart` and `1190-followup-final-probes.log`. No tracked edits or GitHub mutations.
