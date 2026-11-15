# Documentation criteria inspection

Issue1264 chooses the explicitly allowed load-bearing-module statement alternative, not a complete deletion recipe. No runtime source or dependency is deleted; no scratch-copy deletion experiment or one-locale app migration is claimed.

Read the original and replacement Step4, the localization service SupportedLocale enum/fallback, main delegates, localization supported-locales regression, the core DI/network/secure token store/migration imports, ITokenStore contract and linked storage/i18n docs. Localization remains required by routing, shared widgets and screens. The replacement retains those APIs and directs a single-language app to keep one locale, coordinate enum/fallback/ARBs/configuration, preserve delegate adapters, regenerate and update language-specific tests. This is migration guidance, not a promise that deleting non-English files alone is sufficient.

Secure storage remains required by DI, ApiClient, AuthInterceptor, SecureTokenStore and StorageMigrationService. The replacement explicitly retains service/provider/plugin until those consumers migrate. An ITokenStore override alone is explicitly insufficient to remove their concrete imports. It links ordered mutation, snapshot certification and failure/clear requirements and does not suggest ordinary preferences for credentials.

pub outdated now lists newer available dependency versions; it does not claim to discover unused packages. Existing documentation checker passes with no broken links, missing test paths, mismatched signatures or unresolved symbols. No new implementation-mirroring test for reversible prose. Docs-only premerge review exemption applies. Normal full-host and actual CI gates remain required.

Actual CI scope: all seven job checks SUCCESS. Quality runs the markdown-reader subset (752 pass, 2 skips); source codegen/format/analyzer/randomized full tests/coverage/tracked guards are intentionally skipped by its docs-only scope. No coverage claim is made for this PR. The separate host acceptance runner supplies format, analyzer and full-suite verification. Raw job steps and final log tail are preserved.

# Postmerge self-QA

Merged main a03d07d3b1246665549919163e3d8785cf929009 has the same source tree as accepted4ebffa8aacc4f510f8cab112d631ce7c25beadc1. Re-read both replacement sections and actual full-host completion:4,494 tests pass,14 intentional golden skips,format631 unchanged,analyzer no issues,all exit0. Re-ran audit_template after merge with supported_locales and session_token_examples:65 tests pass, format/analyzer clean. Refs checked atmerge; final issue reread confirmssolekoniz-dev owner,open/inprogress andepicdocs. No screenshots, no unverified deletion/migration guarantee. No introduced securitysurface: only guidance preservesexistingcredentialstorage semantics. Solo self-QA pathused for this trivialdocs-onlydiff; noindependent reviewer claimed. Evidenceandmaintainers remotes current beforepublication.
