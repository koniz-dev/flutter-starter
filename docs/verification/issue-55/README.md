# Issue 55 - WCAG AA contrast for every themed colour pair

Evidence for koniz-dev/flutter-starter#55, gathered against `main` at the
squash merge of PR #71 (`122a4bf`).

Produced by `./scripts/test/run_acceptance.sh 55` plus the extra runs listed
below.

## Artifacts

| File | What it is |
|---|---|
| `format.log` | `dart format --set-exit-if-changed lib test integration_test tool examples`, exit 0 |
| `analyze.log` | `flutter analyze`, no issues |
| `tests.log` | full `flutter test`, 2304 passed / 3 skipped (the skipped ones are the `golden`-tagged acceptance tests) |
| `goldens.log` | `flutter test --run-skipped --tags golden test/acceptance`, 3 passed |
| `audit_template.log` | `./scripts/dev/audit_template.sh`, exit 0 |
| `contrast-pairs.log` | `theme_contrast_test.dart` with the expanded reporter: one named line per contrast pair, 36 tests |
| `token-mappings.log` | `default_design_tokens_test.dart` with the expanded reporter: one line per token mapping, 19 tests |
| `regression-demo.log` | `textSecondary` put back to the old `#6C757D` (4.45:1) and both the targeted and the full test run failing |
| `pixel-sample.log` | colours sampled out of the two goldens and rerun through the WCAG formula |
| `theme_text_styles_light.png` | light theme: displayLarge, bodyLarge, bodyMedium, labelLarge, and an ElevatedButton |
| `theme_text_styles_dark.png` | the same surface under the dark theme |
| `home_screen.png` | pre-existing home screen golden, regenerated for the new primary |

## Reading the goldens

`flutter test` renders with the Ahem font, so every glyph is a solid block.
These PNGs prove which rows have ink and at what colour; they cannot show what
any row says. Wording is asserted with `find.text()` inside
`test/acceptance/theme_contrast_acceptance_test.dart`, and the colours are
re-measured numerically in `pixel-sample.log`.
