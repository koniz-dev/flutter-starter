# Source and regression inspection

Selected policy: preserve the receiver's UTC/local zone. Boundaries use that zone's constructors. Comparison clocks are converted into the receiver's zone before calendar-day arithmetic, so UTC fields never mix with local clock fields. Calendar constructors retain DST-safe stepping. Inspected every changed branch and new assertion. No shipped lib caller uses these getters; no source golden counterpart or generator annotation changed.

The valid original-source run fails all four new semantic tests. The corrected baseline records actual offsets +7/+14/-12 and failing results; the fixed 27-test DateTime run records all ten checks true in every zone, plus the existing America/New_York DST regression. Local boundary controls still require local values. The broader extension/guard audit passes 69 tests with clean format/analyzer.

Accepted source and merged main have identical trees. Final host: 4573 tests passed/14 skipped, exit 0. All six final-head CI checks succeeded; Quality: 4572 passed/16 skipped, 96.71% coverage, tracked files unchanged. Fresh merged G2 audit passes 32 tests. Root performs self-QA because this shared-extension diff touches no mandatory adversarial/security surface. See self-qa.md for the final artifact/status inspection. No UI, screenshot, device settings or backend assurance is claimed.
