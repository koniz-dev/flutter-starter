# Independent adversarial premerge review — PR 1278

Verdict: PASS. No new actionable defect found in the three-file change. This is a mechanism review, not a successful store deployment claim.

Reviewed base `8d0e63cf0d6b73fd3c285cc889932a07c77eafde` to head `c35ee6ade3333d7d23537045f3f3af8a14dd6496`, issue 1267's live acceptance criteria, CLAUDE.md, and maintainer process G1b/adversarial review requirements. I did not use the implementer's PASS summary. No tracked files changed, real builds/uploads, full-suite rerun, or outbound mutations were performed.

## Findings and evidence

- All five actual upload lane bodies execute inertly and produce five argument hashes. Every supplied key is valid. All 13 entries of the test's reviewed allowlist also occur in current official supply options; `whatsnew_directory` does not. The two new test predicates both reject the base Fastfile independently: the unknown key remains, and zero calls contain `metadata_path` instead of one.
- The replacement names the Android metadata root, rather than the locale/changelogs directory. I checked Fastlane's parser and runner source, then reproduced its relative `Fastfile` eval filename, execution in `fastlane/`, and the subsequent action cwd at repository root. `__dir__` is `.` in that eval context; `File.expand_path` executes while the lane is in `fastlane/`, producing the correct absolute root before the action changes cwd. Ruby 4.0.6 and macOS system Ruby 2.6.10 pass. A copied adopter tree with spaces in its root passes both versions. No template-owner or repository-name dependency was introduced.
- Official supply options default `skip_upload_changelogs` to false. Its metadata worker gates changelogs separately from listing metadata, and its metadata default discovers `./fastlane/metadata/android` from action cwd. Thus unchanged named lanes continue finding the shipped directory; generic upload explicitly uses its absolute root. Existing listing/image/screenshot skips stay true. Executing the real upstream `upload_changelog` method with inert dependencies and temporary files on both Rubies confirms version-code file precedence and `default.txt` fallback. Actual remote Play metadata updates were not exercised.
- README corrections all match the implementation: Android commands begin at repository root; iOS commands use subshells and leave that cwd intact; custom credential JSON must be added per used call, with only internal carrying the commented example; changelog generation writes repository CHANGELOG.md and does not feed either store; iOS defaults skip metadata and do not consume Android notes; build/upload lanes themselves invoke Flutter IPA builds. macOS Bash 3.2 accepted the subshell/cwd probe. This change introduces no Bash-language dependency.
- The regression evaluates every currently defined upload call rather than scanning option text alone. The source call count and five-result assertion guard against unexecuted calls in this Fastfile. It intentionally skips without Ruby and on Windows; this follows the existing Ruby-backed tooling tests and does not introduce a platform failure. It is not a complete Fastlane integration test, nor a guarantee about future conditional argument branches.
- Scoped Flutter execution passed 25 tests across supply options, artifact paths, pinning forwarding, and release-environment files. `git diff --check` passed; final tracked status was clean. Raw commands, stdout/stderr, and statuses are in `1267-independent-tests.log`.

## Workflows and scope limits

The deploy workflows are manual/template configuration, not normal per-PR upload coverage. Android's commented upload uses the r0adkll GitHub Action and its own staged `distribution/whatsnew` format; it does not consume the fixed supply option. The iOS example invokes deliver separately; this change only corrects README claims about lane builds. Those workflows still require adopter credentials and enabled build/upload steps, and their green/red state cannot prove this Fastlane path. No dormant-workflow regression is introduced by this diff.

The existing hardcoded iOS `Runner.ipa` selection is outside this change and already recorded under open parent 1268, per owner scope information. I did not duplicate it or treat it as fixed.

## Primary references checked 2026-11-15

- [Official upload_to_play_store parameters and changelog semantics](https://docs.fastlane.tools/actions/upload_to_play_store/#parameters)
- [Supply options](https://raw.githubusercontent.com/fastlane/fastlane/master/supply/lib/supply/options.rb)
- [Supply uploader](https://raw.githubusercontent.com/fastlane/fastlane/master/supply/lib/supply/uploader.rb)
- [Fastlane parser](https://raw.githubusercontent.com/fastlane/fastlane/master/fastlane/lib/fastlane/fast_file.rb)
- [Fastlane runner](https://raw.githubusercontent.com/fastlane/fastlane/master/fastlane/lib/fastlane/runner.rb)

Official source snapshots and independent inert probe scripts are retained beside this report in the work directory. Root retains publication, issue/evidence bookkeeping, and merge authority.


# Postmerge independent QA and credential security review — issue 1267

PASS. No new actionable defect or credential exposure found in merged PR 1278 at `a7372ac0f3445e9a1627048d52d742c8196cbc05`.

- Verified exact accepted-head parity for all three changed files against `c35ee6ade3333d7d23537045f3f3af8a14dd6496`. Squash message has `Refs koniz-dev/flutter-starter#1267`; the maintainer refs checker passes for `HEAD^..HEAD`.
- Independently reran only `fastlane_supply_options_test.dart` postmerge: both tests pass, zero skips, exit 0. Builds/uploads remain inert. No full-suite duplicate or real deployment was run.
- Read the actual evidence `format.log`, `analyze.log`, and end of `tests.log`: 635 files unchanged, analyzer clean, 4,508 tests passed with 14 intentional golden skips; all three logs end with exit 0. Inspected draft criterion mappings and root-inspection narrative; the two criteria have named supporting artifacts, and the claims align with the actual Fastfile, README, regression, and independent premerge probes.
- Inspected the final seven-check CI snapshot: all SUCCESS. The actual Quality tail records 4,507 passes/16 skips, clean tracked files, and 96.69% coverage against 94%. Host and CI totals differ and are retained distinctly, rather than asserting identical environments.
- Live read-only issue query confirms issue 1267 is OPEN, `status:in-progress`, `epic:platform-release`, with only assignee `koniz-dev`. Closing/publication remains the owner's action after evidence is committed and pushed.
- Credential review: changed production-reachable generic upload argument only replaces an invalid metadata directory option with supported absolute `metadata_path`. No credentials, auth permissions, service-account payload, logging, or shell interpolation are added to production code. README's custom `json_key_data: ENV[...]` advice passes JSON directly to Fastlane, matching its official option and existing internal-lane example; it does not instruct echoing or committing secret material. The inert regression's current captured payloads contain fixture AAB/configuration values, no supplied credential payload. Existing credential precedence and commented examples are unchanged. No security issue introduced by this diff was found.
- Known IPA-selection work was excluded from this issue and is preserved by the planner's parent/child tracking; it is not claimed fixed or duplicated here.

Raw postmerge commands/stdout/stderr/statuses: `1267-postmerge-independent.log`. Final tracked tree status is clean. Prior independent report remains the detailed review of cwd semantics, Ruby 2.6/4 compatibility, adopter paths, all-five-call coverage, both base negative controls, README corrections and release-note behavior. This postmerge pass does not claim store credentials, upload success, or real-device behavior.

