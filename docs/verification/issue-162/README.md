# Verification evidence - issue #162

docs: the issue-101 evidence README reports test counts that contradict the
tests.log it cites

Verified against `main` at `4076687`, plus the fix in this same change.

## Artifacts

| File | What it is |
|---|---|
| `count-audit.log` | Every `docs/verification/issue-*/README.md` that quotes a pass, skip or test count, printed beside the last `+N ~M` in each `.log` sitting next to it. Generated **after** the fix, so the three corrected rows read correctly in it. |

The shell that produced `count-audit.log`:

```bash
for d in docs/verification/issue-*/; do
  n=${d#docs/verification/issue-}; n=${n%/}
  readme="$d/README.md"; [ -f "$readme" ] || continue
  hits=$(grep -nE '[0-9]{2,4} (passed|pass|tests)|[0-9]+ skipped|\+[0-9]+ ~[0-9]+' "$readme")
  [ -z "$hits" ] && continue
  echo "----- issue-$n -----"
  echo "README lines quoting counts:"; printf '%s\n' "$hits" | sed 's/^/    /'
  for log in "$d"*.log; do
    [ -f "$log" ] || continue
    last=$(grep -oE '\+[0-9]+ ~[0-9]+|\+[0-9]+:' "$log" | tail -1)
    [ -n "$last" ] && echo "    LOG $(basename "$log") last count: $last"
  done
  echo
done
```

## Every README checked, and the verdict

33 evidence directories quote at least one count. Three contradicted their own
log; all three are corrected in this change.

| Directory | README claimed | Log says | Verdict |
|---|---|---|---|
| issue-101 | 2494 passed, 6 skipped | `tests.log` `+2645 ~7` | **WRONG - fixed** to 2645 / 7 |
| issue-117 | 2650 tests, 8 skipped | `tests.log` `+2673 ~8` | **WRONG - fixed** to 2673 / 8 |
| issue-147 | 2708 passed, 8 skipped | `tests.log` `+2728 ~8` | **WRONG - fixed** to 2728 / 8 |
| issue-39 | 2232 tests | `+2232 ~1` | agrees |
| issue-40 | 2233 tests | `+2233 ~1` | agrees |
| issue-48 | 11 pass, 1 skipped; 12 pass | `+11 ~1`; `+12` | agrees |
| issue-50 | `+1923`, `+2099`, `+2229`; 2407 / 5 | all three present in `strip-variants-analyze-test.log`; `+2407 ~5` | agrees |
| issue-52 | 2436 tests; 82 tests | `+2436 ~6`; `+82` | agrees |
| issue-53 | 2443 tests | `+2443 ~6` | agrees |
| issue-54 | `+2407 ~5` | `+2407 ~5` | agrees |
| issue-55 | 2304 passed / 3 skipped; 36; 19 | `+2304 ~3`; `+36`; `+19` | agrees |
| issue-57 | 2422 passed, 5 skipped | `+2422 ~5` | agrees |
| issue-61 | `+2407 ~5`; 440 tests | `+2407 ~5`; `+440` | agrees |
| issue-63 | 2585 tests; 94/22/159/92/397 | `+2585 ~6` and each scoped log | agrees |
| issue-77 | 2422 passed; 59 tests | `+2422 ~5`; `+59` | agrees |
| issue-78 | 2456 tests; 33 tests | `+2456 ~6`; `+33` | agrees |
| issue-88 | `+2407 ~5`; 45 | `+2407 ~5`; `+45` | agrees |
| issue-109 | `+2812 ~8` | `+2812 ~8` | agrees |
| issue-118 | `+2791 ~8` | `+2791 ~8` | agrees |
| issue-121 | 2645 tests; 2688 passed, 8 skipped | `+2645 ~7` (audit runs); `+2688 ~8` (`tests.log`) | agrees |
| issue-142 | 2691 / 8 | `+2691 ~8` | agrees |
| issue-143 | 2705 / 8; 16 tests | `+2705 ~8`; `+16` | agrees |
| issue-160 | `+2691 ~8`, `+2680 ~8`, `+2692 ~8`, `+2715 ~8` | each in the named log | agrees |
| issue-161 | 48 tests | `+48` | agrees |
| issue-167 | `+2794 ~8` | `+2794 ~8` | agrees |
| issue-170 | 2742 tests; 33; 3 | `+2742 ~8`; `+33`; counterfactual | agrees |
| issue-175 | 2768 / 8; 54 tests | `+2768 ~8`; `+54` | agrees |
| issue-177 | 2735 / 8; 33; 72 | `+2735 ~8`; `+33`; `+72` | agrees |
| issue-179 | 2725 tests; 468 tests | `+2725 ~8`; `+468` | agrees |
| issue-180 | 319 tests; 8 skipped | `+319`; `+2794 ~8` | agrees |
| issue-184 | `+2813 ~8` before, `+2812 ~8` after | `tests-before.log`, `tests.log` | agrees |
| issue-187 | `+2277`, `+2464`, `+2607`, `+2794` | the strip probe and `tests.log` | agrees |
| issue-188 | 2780 tests; 12 x3 | `+2780 ~8`; three `+12` logs | agrees |

### One claim that cannot be checked, and is left alone

`docs/verification/issue-40/README.md:131` says a strip run in a clean clone
gave "1770 passing tests". No log for that run was committed, so there is
nothing in the directory for it to contradict - it is an unbacked claim, not a
drift between a README and the log beside it, which is what this issue is about.
Re-deriving it would mean re-running a 2026-09 strip against a tree that has
moved on by ~1000 tests, which would produce a different number and prove
nothing. Recorded here rather than silently "fixed".

## Criteria

| Criterion | Result | Evidence |
|---|---|---|
| 1. the `tests.log` row in `issue-101/README.md` reports the counts in `issue-101/tests.log` | PASS | `count-audit.log`, `----- issue-101 -----`: README line 12 now reads "2645 passed, 7 skipped", `LOG tests.log last count: +2645 ~7` |
| 2. `grep -oE "\+[0-9]+ ~[0-9]+" issue-101/tests.log \| tail -1` and the README agree | PASS | same block: both are `+2645 ~7` |
| 3. every other README quoting a count is checked against its own log; mismatches corrected; the issue comment records which were checked and which were wrong | PASS | the 33-row table above, backed line-by-line by `count-audit.log`; issue-117 and issue-147 were the other two wrong ones and are fixed |
| 4. no file outside `docs/verification/` is modified | PASS | `git diff --name-only origin/main` in the PR body lists only `docs/verification/` paths |
