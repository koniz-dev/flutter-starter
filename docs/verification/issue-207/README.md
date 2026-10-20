# Acceptance evidence - issue #207

`fix(feature-flags): the remote data source dartdoc points at a .template file
that does not exist`

Verified against `main` after PR #246 merged (`cb4a3023ff2`).

## Criterion map

| # | Criterion | Artifact |
|---|---|---|
| 1 | `grep -rn "\.template" lib` names no path that does not exist | `criterion-1-template-grep.log` |
| 2 | the rewritten comment names `FeatureFlagsRemoteDataSource` and `featureFlagsRemoteDataSourceProvider`, and both resolve | `criterion-2-identifiers-resolve.log` |
| 3 | `./scripts/dev/audit_template.sh` exits 0 | `criterion-3-audit_template.log` |
| 4 | `dart run tool/check_docs.dart` exits 0 | `criterion-4-check_docs.log` |

`analyze.log`, `format.log` and `tests.log` are the standard
`scripts/test/run_acceptance.sh 207 --no-goldens` output. Nothing renders here
and the directory holds no `.png`.

## The decision: drop the promise rather than honour it

The issue offered two resolutions and asked for one.

- **Nothing was lost by never having the template.** The contract is five
  methods and no vendor type appears in any signature. Implementing it is
  quicker than reconciling a template with your own project.
- **A template would rot unseen.** `.dart.template` is invisible to
  `flutter analyze` and `flutter test`. The repository already carries that cost
  twice, for the Firebase performance service. A third copy of unanalyzed vendor
  code is a liability in a starter whose selling point is that its gates are
  real.
- **The shipped binding is `NoOpFeatureFlagsRemoteDataSource`.** A comment whose
  headline was "if you want Firebase" described an implementation that does not
  exist, in a slice that is vendorless on purpose.

The reference was not stale - it was never true. Every file ever added under
`lib/features/feature_flags/`, across all refs, is listed in
`criterion-1-template-grep.log`; there is no template among them.

## On naming Firebase

Demoted, not deleted. The comment now lists Firebase Remote Config,
LaunchDarkly, Unleash and a plain JSON endpoint as equal options behind one
contract. A reader who arrived expecting Firebase still finds the word and
learns where it would go, and nobody reads it as the sanctioned choice. This
matches the `docs/architecture/contracts-map.md` row #182 corrected, which
states that no Firebase implementation ships.

## Why no new check was added

#206 wired `<!-- symbol: <path> <Identifier> -->` into `tool/check_docs.dart`.
It covers markdown, not dartdoc inside `lib/`, so it could not have caught this.
Porting it would not have caught it either:

1. **A path-existence scan misses this class of defect.** Prototyped: scanning
   every comment under `lib/` for tokens beginning `lib/`, `test/`, `tool/`,
   `docs/`, `scripts/`, `integration_test/` and the platform directories finds
   **34 references, all of which already resolve**. The token in the broken
   comment was `lib/features/feature_flags/data/datasources/` - a directory that
   exists. What was missing is a file the English promised would be inside it.
2. **The symbol directive is opt-in.** Porting it to dartdoc means inventing a
   Dart-comment directive and hand-annotating, and a directive nobody adds
   catches nothing. The one identifier involved here is in the same file as its
   own dartdoc, where `flutter analyze` already fails a broken `[Reference]`.
3. **The narrow checkable subset now governs nothing.** "Every `*.template` path
   named in `lib/` or `docs/` exists" was worth about fifteen lines - and this
   change removed the only reference it would have covered. If template
   references come back, so should that check.
