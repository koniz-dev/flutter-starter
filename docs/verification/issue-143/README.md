# Issue 143 - `AppTypography` pinned an unbundled Roboto

Verified against merged `main`: PR #185, squash commit `fd3ac29`.

Harness: `./scripts/test/run_acceptance.sh 143`, plus the extra probes listed
below. `./scripts/dev/audit_template.sh` exits 0.

## Decision: drop the pin, do not vendor a font

`AppTypography` declared `fontFamily = 'Roboto'` on all six tokens and nothing
named Roboto is bundled. The constant and the six per-style declarations are
gone; every token now leaves `fontFamily` null and inherits the family
`Typography` already selects per platform. No font file, and therefore no font
licence, was added.

Reasoning, evidenced in `per-platform-behaviour.log`:

- Where the name resolved it was already free. Android and Fuchsia get Roboto
  from the OS and Flutter's own `blackMountainView` text theme names it
  unbundled for exactly that reason. On web the CanvasKit and skwasm renderers
  register Roboto as their own default and download it from
  `fonts.gstatic.com` whenever the app declares no family called `Roboto` -
  `build/web/main.dart.js` carries that URL
  (`criterion-3-web-build-fonts.log`).
- Where it did not resolve it destroyed a correct choice. iOS
  (`CupertinoSystemDisplay`/`CupertinoSystemText`), macOS
  (`.AppleSystemUIFont`) and Windows (`Segoe UI`) were overwritten with a name
  the platform does not have, so the engine fell back silently while
  `ThemeData.textTheme.bodyLarge.fontFamily` still read `'Roboto'`. On Linux
  the pin also dropped the `Ubuntu, Adwaita Sans, Cantarell, DejaVu Sans,
  Liberation Sans, Arial` fallback chain, because it carried no
  `fontFamilyFallback`.
- Bundling would have cost roughly 170 KB per weight in every adopter build
  (four weights are used), an Apache-2.0 `LICENSE` to ship and maintain, and a
  typeface decision a starter template should leave to its adopter.

Nothing depended on the metric difference: `AppTypography` is reached only
through `DefaultDesignTokens` -> `AppTheme.textTheme`, no widget reads the
tokens directly, and the resolved family is unchanged on Android, Fuchsia,
Linux and web.

## Criteria

| # | Criterion | Result | Artifact |
|---|---|---|---|
| 1 | A font is vendored and declared, **or** `AppTypography.fontFamily` is removed with a comment saying so and pointing at where an adopter adds their own | PASS (second branch) | `criterion-1-token-source.log` - the constant and all six `fontFamily:` lines are gone; the class doc explains why and names `pubspec.yaml`'s `fonts:` section and `ThemeData(fontFamily:)` in `lib/shared/theme/app_theme.dart` |
| 2 | `grep -rn "fontFamily" lib/` returns no reference to a family that is not bundled or deliberately absent | PASS | `criterion-2-fontfamily-grep.log` - the only four hits are doc-comment prose in `app_typography.dart`; no Dart expression names a family |
| 3 | If a font is bundled, `flutter build web --release` produces it under `build/web/assets/` and in `FontManifest.json` | N/A - no font bundled; evidenced negatively | `criterion-3-web-build-fonts.log` - `FontManifest.json` lists only `MaterialIcons` and `packages/cupertino_icons/CupertinoIcons`; `find . -name '*.ttf'` outside `build/` returns nothing; `pubspec.yaml` has only the commented-out `fonts:` template |
| 4 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `format.log`, `analyze.log`, `tests.log` (2705 passed, 8 skipped, exit 0) - the same three gates the script runs, each teed by the acceptance runner |

Supporting, beyond the stated criteria:

| Claim | Artifact |
|---|---|
| The resolved family per `TargetPlatform` is now the platform default, light and dark theme, for `displayLarge`, `displayMedium`, `bodyLarge`, `bodyMedium` and `labelLarge` | `platform-font-family-tests.log` - 16 tests pass, and the log embeds the test source so the expected-family table is readable |
| Apple targets no longer resolve to Roboto | same log, test `apple targets no longer resolve to Roboto` |
| The Linux fallback chain survives | same log, test `the linux fallback chain is preserved` |
| No painted pixel changed | `goldens.log` (11 golden tests pass against the committed goldens) and `goldens-checksums.txt` |

## About the PNGs in this directory

`run_acceptance.sh` copies every standing golden under `test/acceptance/goldens/`
into the evidence directory. All 13 were opened and inspected. They are
byte-identical to the repository's goldens - each pair in
`goldens-checksums.txt` shares a hash - so they show that this change repainted
nothing.

**No criterion rests on them, and none can.** `flutter test` renders every
glyph with the test font regardless of `fontFamily`: in every one of these PNGs
the text is opaque black blocks. A golden here is incapable of distinguishing
"Roboto resolved", "Roboto fell back" and "no family set", which is precisely
why the evidence for this issue is the resolved `TextStyle` on `ThemeData`
rather than a screenshot.

## Not established here

Real-glyph rendering on a device. No Android or iOS device or emulator is
attached to this environment, so nothing below was observed, only derived from
the Flutter SDK sources quoted in `per-platform-behaviour.log`:

- that Android's system font manager resolves the name `Roboto` (the framework
  itself relies on this - it names Roboto, unbundled, for android/fuchsia);
- how any of these faces look when drawn.

Neither is load-bearing. The defect was that the design system overrode the
framework's per-platform family with an unbundled name, and the fix is that it
no longer does - a property of the resolved `ThemeData`, which is fully
testable here.

## Files

| File | What it is |
|---|---|
| `format.log` | `dart format --set-exit-if-changed lib test integration_test tool examples` |
| `analyze.log` | `flutter analyze` |
| `tests.log` | `flutter test` (unit + widget, goldens skipped) |
| `goldens.log` | `flutter test --run-skipped --tags golden test/acceptance` |
| `goldens-checksums.txt` | SHA-256 of `test/acceptance/goldens/*.png` and the copies here |
| `criterion-1-token-source.log` | merged commit plus the full post-change `app_typography.dart` |
| `criterion-2-fontfamily-grep.log` | `grep -rn "fontFamily" lib/` and a broader `font` grep |
| `criterion-3-web-build-fonts.log` | release web build: `FontManifest.json`, bundled font files, the engine's Roboto CDN URL, `pubspec.yaml` `fonts:` state |
| `platform-font-family-tests.log` | the per-`TargetPlatform` font-family tests and their source |
| `per-platform-behaviour.log` | how the per-platform behaviour was established: Flutter SDK sources and host font directories |
| `*.png` | the 13 standing acceptance goldens, unchanged; see above |
