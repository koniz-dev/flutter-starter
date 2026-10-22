# Flutter Starter

A Flutter app built on Clean Architecture: domain, data and presentation layers
per feature, Riverpod for state and dependency injection, and a Dio-based
network layer behind a transport-agnostic contract.

What is in the box:

- **Auth** with token refresh, session restore and forced logout. Until you
  set `BASE_URL`, a debug build signs in offline with a demo account, so the
  app runs end to end before you have a backend.
- **Two sample features**, `tasks` (local CRUD) and `feature_flags`, showing a
  complete slice each.
- **Configuration** layered from `.env`, `--dart-define` and per-environment
  defaults ([Configuration](docs/guides/configuration.md)).
- **Optional hardening**: certificate pinning, and RASP via `freerasp`, which
  is a no-op until you wire it ([Security](docs/guides/security/implementation.md)).
- **Tests** mirroring `lib/` (unit and widget), acceptance goldens, and Patrol
  end-to-end tests in `integration_test/`.
- **Tooling**: Conventional Commits and format/analyze hooks, CI on every pull
  request, feature scaffolding, release and deploy scripts.

## Getting started

```bash
flutter pub get
./scripts/dev/setup_git_hooks.sh
flutter run
```

Generated code (Freezed, json_serializable, Riverpod) is committed; run
`flutter pub run build_runner build --delete-conflicting-outputs` only after
changing an annotated source.

To point the app at your API, copy the example environment file, set
`BASE_URL` in it, and pass it to the build:

```bash
cp .env.example .env
flutter run --dart-define-from-file=.env
```

`.env` is a build input, never a Flutter asset, so it does not ship inside the
app. Without `--dart-define-from-file`, `flutter run` uses the built-in
development defaults.

Before pushing, run the same checks CI runs:

```bash
./scripts/dev/audit_template.sh
```

## Working on the project

- [Getting started](docs/guides/onboarding/getting-started.md) - setup,
  environments, running on each platform
- [Understanding the codebase](docs/guides/onboarding/understanding-codebase.md)
  and [Architecture](docs/architecture/README.md)
- [Adding a feature](docs/api/examples/adding-features.md) - scaffold one with
  `./scripts/dev/create_feature.sh <name>`
- [Testing](docs/guides/testing/testing-summary.md), including the Patrol
  end-to-end tests ([`integration_test/README.md`](integration_test/README.md))
- [Deployment](docs/deployment/README.md) - store builds and CI
- [All documentation](docs/README.md)

Contribution conventions (branches, commits, the quality gate) are in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Using this template

This section is for setting the project up from the template. Delete it once
that is done.

- **Rename** the package, display name and application ids:
   [Fork and customize](docs/guides/onboarding/fork-and-customize.md).
- **Brand** it: put your logo at `assets/images/logo.png` and run
   `./scripts/dev/setup_branding.sh` for launcher icons and splash screens.
- **Drop what you do not need.** `dart run tool/strip_sample_features.dart --apply` removes both sample features; see [`tool/README.md`](tool/README.md) for the variants. <!-- strip:strip-tool line -->
- **Connect your backend** by setting `BASE_URL`, which also turns the demo
   sign-in off ([how to remove it](docs/guides/onboarding/getting-started.md#signing-in-before-you-have-a-backend)).

<!-- strip:bricks start -->
The rename can also be done with Mason: `dart pub global activate mason_cli`,
`mason get`, then `mason make flutter_starter_setup` ([bricks/README.md](bricks/README.md)).
If you rename by hand instead, drop the bricks with `dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks`, or add `--remove-bricks` to whichever strip you run. <!-- strip:strip-tool line -->
<!-- strip:bricks end -->

## License

MIT - see [LICENSE](LICENSE).
