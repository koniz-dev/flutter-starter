# Deployment

Store and CI deployment for this starter are **templates**: workflows default to **manual** (`workflow_dispatch`) until you uncomment triggers and add secrets.

## Where to look

| Topic | Location |
| --- | --- |
| **GitHub Actions** | [`.github/workflows/deploy-android.yml`](../../.github/workflows/deploy-android.yml), [`.github/workflows/deploy-ios.yml`](../../.github/workflows/deploy-ios.yml), [`.github/workflows/deploy-web.yml`](../../.github/workflows/deploy-web.yml), [`.github/workflows/build.yml`](../../.github/workflows/build.yml) |
| **Fastlane (local / lane reference)** | [`fastlane/README.md`](../../fastlane/README.md) |
| **Android credentials & Play upload** | [Android deployment](android-deployment.md) |
| **iOS signing & App Store Connect** | [iOS deployment](ios-deployment.md) |
| **Release checklist** | [Deployment summary](summary.md) |

## Quick path

1. Fork/rename the app ([Fork and customize](../guides/onboarding/fork-and-customize.md)).
2. Configure signing, bundle IDs, and store API keys (see Android / iOS pages above).
3. Open the workflow you need in GitHub **Actions** and use **Run workflow** (or enable `push` / `tags` triggers in the YAML when ready).

The build and deploy steps ship commented out. Until you uncomment them, a run
fails on purpose rather than going green having deployed nothing: every
deploy job uploads its build with `if-no-files-found: error`, and each
`deploy-web.yml` job ends in a "Fail while nothing is deployed" step - delete
that step once its build and deploy steps are live.

## Related docs

- [Configuration](../guides/configuration.md) — `BASE_URL`, flavors, and `dart-define`.
- [Security implementation](../guides/security/implementation.md) — obfuscation, pinning, release hardening.
