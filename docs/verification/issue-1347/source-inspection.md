# Tooling contract inspection

PowerShell alternative: scripts/dev/create_feature.ps1 header and scripts/README.md explicitly require PowerShell7+ (pwsh), not WindowsPowerShell5.1. Runtime scaffold/output is unchanged; no native5.1 or real Windows run is claimed. Existing culture/parity tests included in focused audit.

Pre-commit export cost: header and troubleshooting hooks section say every commit exports the whole tracked repository, including unrelated monorepo assets; runtime and temporary disk usage scale with the whole tracked tree. checkout-index --all behavior remains unchanged, preserving staged-source/path-dependency fidelity.

Pre-push header and troubleshooting now state tests run on working tree, not pushed tips; uncommitted edits affect results. Ref classification uses remote tag destination and zero local OID deletions, consumes mixed pushes before deciding, runs once for any branch update and for empty/manual input. TTY invocation does not block waiting for refs. Existing Git environment cleanup/monorepo app selection remains unchanged.

release.sh invokes existing shared formatter --check before Step1 and any release file/branch mutation; existing format helper has read-only behavior. Implicit changelog version uses the same comment/whitespace/CR/build-number normalization as release.sh. No generator annotations or strip golden counterparts changed; no screenshots or native/store/backend claims.
