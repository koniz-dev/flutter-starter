# Issue 1268 - P3 findings of the 2026-11-14 audit

Every box is ticked by a merged change. Code and tooling boxes were promoted to their own issues (1279-1292), each closed with its own evidence directory; the documentation boxes and the web note merged in PR 1307 (squash `f62242a4a15`). Gates on `main` at `f62242a4 docs: close the documentation findings of the 2026-11-14 audit (#1307)`.

| Criterion | Artifact | Result |
|---|---|---|
| Doc boxes match the code | PR 1307 table (each box checked against the code it cites); `check_docs.log` | docs check passes |
| `overview.md:143` clause in a `strip:feature-flags` region | `overview-after-strip.log` (fresh clone, `--remove-feature-flags`) | the paragraph reads true without the sample; 0 `feature_flags` mentions left |
| Web multi-tab (reasoning only) | `docs/guides/security/audit.md` "On web, the session is per tab while the tokens are shared" | limitation stated next to the localStorage note, with the remedy - the option the box allows |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited.
