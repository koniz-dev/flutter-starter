# Issue 82 - contrast maths ignores the alpha channel

Fix merged as `fdf2832` (PR #151). Evidence produced on the merged `main`.

## What the fix does

`AccessibilityHelpers._getRelativeLuminance` read only `color.r/g/b`, so a
translucent colour was scored as if fully opaque. Semantics now, documented on
`getContrastRatio`, `meetsContrastRatioAA`, `meetsContrastRatioAALarge` and
`meetsContrastRatioAAA`:

- a translucent **foreground** is composited over the supplied background
  (source-over in gamma-encoded sRGB, the space the renderer paints in) and the
  composited pixel is measured;
- a translucent **background** is rejected with an `ArgumentError`, because the
  colour painted behind it was never supplied.

## Per-criterion artifacts

| # | Criterion | Artifact |
|---|---|---|
| 1 | `getContrastRatio(Color(0xB3FFFFFF), Color(0xFF121212))` returns the composited ratio; a unit test asserts it and fails against the old implementation | `criterion-1-alpha-tests.log` (8/8 pass, the composited value is 9.48:1), `criterion-1-regression-demo.log` (same tests against the pre-fix helper: 8 failures, the first reporting `Actual: <18.733663902900595>`) |
| 2 | Opaque behaviour unchanged; at least three existing opaque pairs pinned to today's ratios | `criterion-2-opaque-pins.log` (five pairs pinned to 14.63, 5.89, 5.22, 9.03, 16.67 - the ratios `docs/verification/issue-55/pixel-sample.log` measured off real painted pixels). The same five pass against the pre-fix helper in `criterion-1-regression-demo.log`, which is what makes them a re-baselining guard rather than a restatement |
| 3 | Semantics documented on the public entry points | `criterion-3-documented-semantics.log` |
| 4 | No currently-passing pair turned failing | `criterion-4-theme-contrast.log` (all 33 pinned theme pairs still measure their pinned ratio; the diff shows no pinned number was edited) |
| 5 | `./scripts/dev/audit_template.sh` exits 0 | `criterion-5-audit_template.log`, plus `format.log`, `analyze.log`, `tests.log` from `run_acceptance.sh` |

## About the PNGs

`run_acceptance.sh` copies every file under `test/acceptance/goldens/` into this
directory. **No criterion of issue 82 rests on any of them.** This change alters
no painted pixel - only how a ratio is computed from two colours - so the
goldens are expected to be byte-identical to the repository's, and they are:
`goldens-checksums.txt` shows each copy matching its `test/acceptance/goldens/`
source. The twelve files carry eight distinct hashes; all eight distinct images
were opened and inspected. `theme_text_styles_light.png` and
`theme_text_styles_dark.png` are the closest to this issue and confirm what is
expected - unchanged ink colours, including the opaque light-grey dark
`bodyMedium` row that #55 moved off `Colors.white70`. Remember Ahem renders
every glyph as a block: these prove colour and presence, never wording.
