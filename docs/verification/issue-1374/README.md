# Issue 1374 evidence

- `spinner-contrast-test-before-fix.log`: the new test
  `test/features/tasks/presentation/screens/tasks_app_bar_spinner_contrast_test.dart`
  run against unchanged `lib/` at main `d2f223b6a25` (before the fix). The two
  light-theme cases fail with `Actual: <1.0>`, and the two dark cases pass.
- `spinner-contrast-test-after-fix.log`: the same test at merge `00469a9b513`,
  with all 4 cases passing (expanded reporter).
- `spinner_ratio_probe_test.dart` and `spinner-ratio-probe-after-fix.log`: a copy
  of that test that also prints the measured colours and ratio. It was run from
  `test/` at `00469a9b513` and then removed. Light: ffffffff on ff0069d9 =
  5.22:1 on both screens. Dark: ffffffff on ff1e1e1e = 16.67:1 on both screens.
- `format.log`, `analyze.log`, `tests.log`, `goldens.log`: run_acceptance.sh at
  `00469a9b513`.
- `*.png`: the repository's standing goldens, byte-identical to
  `test/acceptance/goldens/` (see `goldens-checksums.txt`). No criterion rests
  on them.
