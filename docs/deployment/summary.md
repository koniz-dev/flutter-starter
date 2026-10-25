# Deployment summary

Short checklist before shipping a build from this starter.

## Before you tag or upload

- [ ] Version and build number bumped (`pubspec.yaml`, platform-specific rules).
- [ ] `BASE_URL` / environment matches the target (staging vs production).
- [ ] Release signing configured (Android keystore, iOS certificates/profiles).
- [ ] Store listings, privacy policy, and data safety forms updated (store consoles).
- [ ] [Security checklist](../guides/security/checklist.md) reviewed for production.

## Automation

- **Quality gate:** [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — format, analyze, unit tests, and a total line coverage floor (`COVERAGE_MIN_TOTAL`).
- **Coverage (optional cadence):** [`.github/workflows/coverage.yml`](../../.github/workflows/coverage.yml).
- **Dependency updates:** [`.github/dependabot.yml`](../../.github/dependabot.yml) opens weekly PRs for pub packages and GitHub Actions, with minor and patch bumps grouped into one PR per ecosystem. `patrol` is excluded because it must be bumped together with the `patrol_cli` version pinned in [`e2e-android.yml`](../../.github/workflows/e2e-android.yml). To stop the PRs, delete `dependabot.yml` (or one of its `updates:` entries). Security updates are a separate repository setting (Settings → Code security).
- **Deploy:** [Deployment hub](README.md) lists Android/iOS/web workflows — usually **manual** until you wire secrets and triggers.

## Deeper guides

- [Deployment hub](README.md)
- [Android deployment](android-deployment.md)
- [iOS deployment](ios-deployment.md)
- [Fastlane README](../../fastlane/README.md)
