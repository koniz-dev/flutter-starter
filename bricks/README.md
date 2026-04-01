# Mason bricks (fork tooling)

This directory holds **[Mason](https://pub.dev/packages/mason_cli) bricks** used **once** when you fork the template: rename the Dart package, Android `applicationId` / namespace, iOS bundle id, and optionally strip sample features.

- **Not runtime code** — nothing here is compiled into the Flutter app.
- **Registered in** [`mason.yaml`](../mason.yaml) at the repo root.
- **Bricks in this repo:**
  - [`flutter_starter_setup`](flutter_starter_setup/README.md) — one-time fork/rename tooling.
  - [`feature_clean`](feature_clean/README.md) — generate a new clean-architecture feature module.

## Quick use

From the repository root (after `dart pub global activate mason_cli`):

```bash
mason get
mason make flutter_starter_setup
```

Then `flutter pub get && flutter analyze && flutter test`.

## If you do not use Mason

You can delete the whole **`bricks/`** folder and **`mason.yaml`** after you finish renaming manually (see [Fork and customize](../docs/guides/onboarding/fork-and-customize.md)). That shrinks the tree; CI still formats any remaining `bricks/` path only if the folder exists.

## Developing or changing a brick

- Hook code lives under `bricks/<name>/hooks/` (a small Dart package).
- After editing hooks, run `dart pub get` inside `bricks/flutter_starter_setup/hooks/` so analysis and Mason resolve dependencies locally.
- `brick.yaml` `environment.mason` and `hooks/pubspec.yaml` should stay aligned with the root `pubspec.yaml` **`mason`** dev_dependency (currently the stable `^0.1.x` line from [pub.dev](https://pub.dev/packages/mason)).
