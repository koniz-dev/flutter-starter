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
