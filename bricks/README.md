# Mason bricks (fork tooling)

This directory holds **[Mason](https://pub.dev/packages/mason_cli) bricks** used **once** when you fork the template: rename the Dart package, Android `applicationId` / namespace, iOS bundle id, and optionally strip sample features.

- **Not runtime code** — nothing here is compiled into the Flutter app.
- **Registered in** [`mason.yaml`](../mason.yaml) at the repo root.
- **Bricks in this repo:**
  - [`flutter_starter_setup`](flutter_starter_setup/README.md) — one-time fork/rename tooling.
  - [`feature_clean`](feature_clean/README.md) — generate a new clean-architecture feature module.

## Quick use

From the repository root (after `dart pub global activate mason_cli`).
`mason` must be on `PATH`: `dart pub global activate` puts it in
`~/.pub-cache/bin`, so run `export PATH="$PATH":"$HOME/.pub-cache/bin"` first
(or prefix each command with `dart pub global run mason_cli:`); otherwise
they fail with `mason: command not found`. See
[Fork and customize](../docs/guides/onboarding/fork-and-customize.md).

```bash
mason get
mason make flutter_starter_setup
```

Then `flutter pub get && flutter analyze && flutter test`.

## If you do not use Mason

You can remove the whole **`bricks/`** folder and **`mason.yaml`** after you finish renaming manually (see [Fork and customize](../docs/guides/onboarding/fork-and-customize.md)).
Use `dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks`, which also drops the docs that link into them. <!-- strip:strip-tool line -->
That shrinks the tree.

## Developing or changing a brick

- Hook code lives under `bricks/<name>/hooks/` (a small Dart package) in both bricks: `pre_gen.dart` validates the input through `input_rules.dart` before anything is written, and `post_gen.dart` runs after generation.
- After editing any file under a brick's `hooks/` (`pre_gen.dart`, `post_gen.dart`, `input_rules.dart` or `pubspec.yaml`), run `dart pub get` inside that brick's `hooks/` folder - `bricks/flutter_starter_setup/hooks/` or `bricks/feature_clean/hooks/` - so analysis and Mason resolve dependencies locally.
- `brick.yaml` `environment.mason` and `hooks/pubspec.yaml` should stay aligned with the root `pubspec.yaml` **`mason`** dev_dependency (currently the stable `^0.1.x` line from [pub.dev](https://pub.dev/packages/mason)).
