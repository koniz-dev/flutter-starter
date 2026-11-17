# Issue 1292 - iOS lanes pick up the exported IPA by glob

Merged: PR 1305, squash `2526cefb2d7`. Gates on `main` at `2526cefb fix(release): select exported IPA artifacts without assuming Runner.ipa (#1305)`.

| Criterion | Artifact | Result |
|---|---|---|
| The lanes pick up `build/ios/ipa/*.ipa` | `ios_ipa_tests.log` (`fastlane_ios_ipa_test.dart` runs `fastlane/ios_ipa.rb` in Ruby; `fastlane_artifact_paths_test.dart`; `deploy_upload_examples_test.dart`) | one IPA found whatever its name; none or two refused with names; `clear` removes earlier exports; no lane or upload step names `Runner.ipa`; both lanes clear before building |
| Upload step | pre-merge review (PR 1305 body) ran the uncommented step under `bash -e` with 0, 1 (name with spaces) and 2 IPAs | passes the one IPA's absolute path; refuses 0 and 2 |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

Not run: fastlane itself and an Apple signing identity are not available here, so no lane was run end to end (tier 3, adopter's environment). No screenshots.
