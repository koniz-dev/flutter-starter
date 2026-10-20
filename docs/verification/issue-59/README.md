# Issue 59 - acceptance evidence

Verified against PR #87 (squash commit `98cd15b` on `main`).

`./scripts/test/run_acceptance.sh 59` produced `format.log`, `analyze.log`,
`tests.log`, `goldens.log` and the four PNGs. The per-criterion logs were
captured separately so each criterion names one artifact.

| Criterion | Artifact |
|---|---|
| 1. every exit completes all queued handlers | `criteria-1-2-4-5_refresh_queue.log` |
| 2. `_isRefreshing` reset in `finally`, catch covers `Error` | `criteria-1-2-4-5_refresh_queue.log` |
| 3. retry client uses the pinned adapter | `criteria-3-6_ssl_pinning.log` |
| 4. one retry client, closed on dispose | `criteria-1-2-4-5_refresh_queue.log` |
| 5. original `cancelToken` propagated | `criteria-1-2-4-5_refresh_queue.log` |
| 6. loud failure on pinning without fingerprints; effective state reported | `criteria-3-6_ssl_pinning.log`, `criterion-6_config_reporting.log` |
| 7. no live network call under `test/core/network/` | `criterion-7_no_live_network.log`, `criterion-7_network_suite.log` |
| 8. `audit_template.sh` exits 0 | `criterion-8_audit_template.log` |

## About the PNGs

`home_screen.png`, `cold_start_no_session.png`, `cold_start_restored_session.png`,
`theme_text_styles_light.png` and `theme_text_styles_dark.png` are the
repository's standing acceptance goldens, captured by the harness on every run.
They show the app still renders normally after this change; none of them is
evidence for a criterion of this issue, which is all transport-layer behaviour
with no visual surface. Every glyph in them is an opaque Ahem block, so they
prove layout and colour only, never wording.

## Not covered here

End-to-end MITM proof for criterion 3 needs a physical device with a custom CA
installed - tier 3. The wiring is asserted in tier 1
(`criteria-3-6_ssl_pinning.log`: the replay client resolves to the same
`IOHttpClientAdapter` instance as the main client); the interception attempt
itself is routed to `status:needs-uat`.
