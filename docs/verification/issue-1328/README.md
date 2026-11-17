# Issue 1328 - the v4 to v5 upgrade notes miss the new UI packages and the scene manifest

Merged: PR 1333, squash `5e4bdec`. Release notes edited with `gh release edit v5.0.0`; maintainers changelog commit `45353118504`. Gates on `main` at `8b9b4a2c test(auth): the demo card fits 360dp at 2x text in every locale (#1339)`.

| Criterion | Artifact | Result |
|---|---|---|
| `upgrading-this-starter.md` has a "v4 to v5" section under Breaking Changes by Version | `guide-headings.txt`: `## Breaking Changes by Version` (line 112), then `### v4 to v5 (starter v5.0.0)` (line 114) | present |
| It says to add `material_ui ^1.11.0` and `cupertino_ui ^1.1.6` to `pubspec.yaml` and to copy `UIApplicationSceneManifest` with the AppDelegate change | `guide-v4-to-v5-section.md` lines 8-16 (pubspec block) and 22-24 (scene manifest) | stated |
| The standalone UI section moves under it | `guide-headings.txt`: `#### Standalone UI libraries on Flutter 3.50` (line 145) inside the v4 to v5 section | moved |
| The v5.0.0 GitHub release notes are corrected the same way and point at the guide | `release-notes.diff` (before vs after `gh release view v5.0.0`): the UIScene entry adds the manifest and the guide's section; the dependency entry names both packages as new and points at the section | corrected |
| The maintainers changelog matches | `changelog-commit.diff`; `changelog-vs-release.diff` is empty: the changelog's `[5.0.0]` section equals the published notes, blank lines aside | matches |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited.
