<div align="center">

# Flutter Starter

**A production-ready Flutter template on Clean Architecture that you configure, not rebuild.**

Auth with token refresh, a pinned HTTP layer, secure storage, routing,
localization, theming and three tiers of tests are already wired together and
tested. Every external service sits behind a small contract with a no-op
default, so pointing the app at your backend and providers takes configuration
and an adapter, not a rewrite.

[![CI](https://github.com/koniz-dev/flutter-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/koniz-dev/flutter-starter/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/koniz-dev/flutter-starter)](https://github.com/koniz-dev/flutter-starter/releases)
[![Flutter 3.47+](https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter)](https://docs.flutter.dev/)
![Android | iOS | Web | Desktop](https://img.shields.io/badge/platforms-Android_%7C_iOS_%7C_Web_%7C_Desktop-blue)
[![very_good_analysis](https://img.shields.io/badge/style-very__good__analysis-B22C89)](https://pub.dev/packages/very_good_analysis)
[![MIT license](https://img.shields.io/github/license/koniz-dev/flutter-starter)](LICENSE)

[**Use this template**](https://github.com/koniz-dev/flutter-starter/generate)
· [Getting started](docs/guides/onboarding/getting-started.md)
· [Documentation](docs/README.md)
· [Releases](https://github.com/koniz-dev/flutter-starter/releases)

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/koniz-dev/flutter-starter/readme-assets/ios-login-light.png" width="200" alt="The sign-in screen in light mode, offering the offline demo account">
  <img src="https://raw.githubusercontent.com/koniz-dev/flutter-starter/readme-assets/ios-tasks-light.png" width="200" alt="The tasks sample listing incomplete and completed tasks in light mode"> <!-- strip:tasks line -->
  <img src="https://raw.githubusercontent.com/koniz-dev/flutter-starter/readme-assets/ios-task-detail-dark.png" width="200" alt="Editing a task in dark mode"> <!-- strip:tasks line -->
  <img src="https://raw.githubusercontent.com/koniz-dev/flutter-starter/readme-assets/ios-feature-flags-dark.png" width="200" alt="The feature flags debug screen in dark mode"> <!-- strip:feature-flags line -->
</p>

<p align="center"><sub>Captured on the iOS Simulator in light and dark mode, with no backend
configured. The same code builds for Android, the web and desktop.</sub></p>

## Why this starter

- **Runs before you have a backend.** Until you set `BASE_URL`, a debug build
  signs in offline with a demo account, so the whole app works end to end on
  day one. Setting it turns the demo off.
- **No vendor lock-in.** Storage, networking, error reporting, performance
  tracing and RASP each sit behind a contract with a no-op or local default,
  and the Crashlytics, Firebase Performance, freeRASP and GraphQL integrations
  ship as templates rather than dependencies
  ([Contracts and adapter map](docs/architecture/contracts-map.md)).
- **Safe release builds.** A staging or production build refuses to start on
  a development configuration, a `BASE_URL` that is not https, or certificate
  pinning with no fingerprints, instead of shipping quietly misconfigured.
- **Verified, not assumed.** Every pull request runs format, analysis with
  `very_good_analysis`, the full test suite under a 94% line coverage floor,
  and checks that the docs' code, paths and commands still match the code
  ([Quality gates](#quality-gates)).
- **Yours in a few commands.** A Mason brick renames the package, app name and
  application ids, and one command removes the sample features
  ([Using this template](#using-this-template)).

## Quick start

```bash
flutter pub get                    # Flutter 3.47+ (Dart 3.13+)
./scripts/dev/setup_git_hooks.sh   # format and analyze on commit, Conventional Commits
flutter run                        # no BASE_URL yet: sign in with the demo account
```

To point the app at your API, copy the example environment file, set
`BASE_URL` in it, and pass it to the build:

```bash
cp .env.example .env
flutter run --dart-define-from-file=.env
```

`.env` is a build input, never a Flutter asset, so it does not ship inside the
app. Without `--dart-define-from-file`, `flutter run` uses the built-in
development defaults.

Generated code (Freezed, json_serializable, Riverpod) is committed; run
`flutter pub run build_runner build --delete-conflicting-outputs` only after
changing an annotated source. Details, platforms and troubleshooting:
[Getting started](docs/guides/onboarding/getting-started.md).

## What you get

| Area | What is in place | Docs |
|---|---|---|
| **Architecture** | Domain, data and presentation layers per feature, Riverpod for state and dependency injection, contracts in `lib/core/contracts` with adapters alongside | [Architecture](docs/architecture/README.md) |
| **Auth and session** | Sign-in and registration, token refresh with retry, session restore on launch, forced logout; tokens in the iOS Keychain / Android Keystore | [Auth repositories](docs/api/features/auth/repositories.md) |
| **Networking** | Dio behind a transport-agnostic client, the token sent only to the API's own origin, certificate pinning, an HTTP cache, redacted logs, and a WebSocket realtime client | [Security](docs/guides/security/implementation.md) |
| **Configuration** | `.env` layering, `--dart-define` and per-environment defaults; a release build checks its configuration at startup | [Configuration](docs/guides/configuration.md) |
| **Routing** | go_router with signed-in and signed-out guards and a not-found screen | [Routing](docs/guides/features/routing-guide.md) |
| **UI** | Material 3 design tokens with light and dark themes, accessibility helpers, and English, Spanish, Arabic (RTL) and Vietnamese | [Internationalization](docs/guides/features/internationalization-guide.md), [Accessibility](docs/guides/accessibility/README.md) |
| **Observability** | A logging service, plus error-reporting and performance seams with no-op defaults | [Performance](docs/guides/performance/README.md) |
| **Tests** | Unit and widget tests mirroring `lib/`, acceptance goldens, and Patrol end-to-end tests | [Testing](docs/guides/testing/testing-summary.md) |
| **Tooling** | Git hooks, CI, feature scaffolding, release scripts, fastlane lanes and deploy workflows | [Deployment](docs/deployment/README.md) |
| **Sample: tasks** | A complete removable slice: local create, edit, complete and delete | [`lib/features/tasks`](lib/features/tasks) | <!-- strip:tasks line -->
| **Sample: feature flags** | A complete removable slice: compile-time and local flags with a debug screen | [`lib/features/feature_flags`](lib/features/feature_flags) | <!-- strip:feature-flags line -->


## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.47+, Dart 3.13+ |
| State and DI | Riverpod 3 with code generation |
| Navigation | go_router 18 |
| Networking | Dio 5, `web_socket_channel` for realtime |
| Models | Freezed 4, json_serializable |
| Storage | flutter_secure_storage 11 for tokens, shared_preferences for the rest |
| Localization | `flutter_localizations` and `intl`, ARB files |
| Testing | flutter_test, mocktail, Patrol |
| Tooling | very_good_analysis, Mason, fastlane, GitHub Actions |

## Project structure

```
lib/core/          the foundation: config, network, session, storage, routing, logging, security
lib/features/<f>/  one slice per feature: domain/, data/, presentation/, di/, routing/
lib/shared/        design system, theme, shared widgets
test/              unit and widget tests, mirroring lib/; acceptance goldens in test/acceptance/
integration_test/  Patrol end-to-end tests
scripts/, tool/    developer, CI and release scripts; docs and repository checks
```

Presentation and data depend on domain, and domain depends on neither. See
[Understanding the codebase](docs/guides/onboarding/understanding-codebase.md).

## Quality gates

Every pull request runs the Quality gate:

- format, and `flutter analyze` with `very_good_analysis`;
- the full test suite in random order, with a 94% total line coverage floor;
- a check that `flutter pub get` and code generation leave the tree unchanged.

Pull requests that touch them also run the docs check (the docs' code samples,
paths, symbols and commands must match the code), action pinning and workflow
lint, an Android build on the JDK floor, and the git hook and release script
tests. Patrol on an Android emulator, per-layer coverage and the store builds
run manually or weekly, not per pull request. Run the same gate locally:

```bash
./scripts/dev/audit_template.sh
```

## Documentation

Start with [docs/README.md](docs/README.md). The usual path:

1. [Getting started](docs/guides/onboarding/getting-started.md) - setup,
   environments, running on each platform.
2. [Understanding the codebase](docs/guides/onboarding/understanding-codebase.md)
   and [Architecture](docs/architecture/README.md).
3. [Adding a feature](docs/api/examples/adding-features.md) - scaffold one with
   `./scripts/dev/create_feature.sh <name>`.
4. [Testing](docs/guides/testing/testing-summary.md), including the Patrol
   end-to-end tests ([`integration_test/README.md`](integration_test/README.md)).
5. [Deployment](docs/deployment/README.md) - store builds and CI.

Contribution conventions (branches, commits, the quality gate) are in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Using this template

This section is for setting the project up from the template. Delete it once
that is done, together with the parts above that describe the template rather
than your app: the badges and links under the title, the screenshots, "Why
this starter", and the Support section below.

- **Rename** the package, display name and application ids:
   [Fork and customize](docs/guides/onboarding/fork-and-customize.md).
- **Brand** it: put your logo at `assets/images/logo.png` and run
   `./scripts/dev/setup_branding.sh` for launcher icons and splash screens.
- **Drop what you do not need.** `dart run tool/strip_sample_features.dart --apply` removes both sample features; see [`tool/README.md`](tool/README.md) for the variants. <!-- strip:strip-tool line -->
- **Connect your backend** by setting `BASE_URL`, which also turns the demo
   sign-in off ([how to remove it](docs/guides/onboarding/getting-started.md#signing-in-before-you-have-a-backend)).
   Requests go to `BASE_URL` + `/v1`, and sign-in expects the
   [auth wire format](docs/api/features/auth/models.md#wire-format); see
   [Connecting your backend](docs/guides/onboarding/getting-started.md#connecting-your-backend).
- **Keep up with the template**: the
   [upgrade guide](docs/guides/migration/upgrading-this-starter.md) records
   which release your copy came from and how to take in later ones.

<!-- strip:bricks start -->
The rename can also be done with Mason: `dart pub global activate mason_cli`,
`mason get`, then `mason make flutter_starter_setup` ([bricks/README.md](bricks/README.md)).
If you rename by hand instead, drop the bricks with `dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks`, or add `--remove-bricks` to whichever strip you run. <!-- strip:strip-tool line -->
<!-- strip:bricks end -->

## Support

Bugs and questions go to
[GitHub issues](https://github.com/koniz-dev/flutter-starter/issues); every
release and its upgrade notes are on the
[Releases](https://github.com/koniz-dev/flutter-starter/releases) page.
Report a vulnerability privately from the repository's **Security** tab, not
in a public issue.

## License

MIT - see [LICENSE](LICENSE).
