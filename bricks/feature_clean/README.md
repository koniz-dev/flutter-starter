# feature_clean

Generates a new feature module under `lib/features/<feature_name>/` following the starter's conventions:

- `data/` — datasources, models, repository implementations
- `domain/` — entities, repository contracts, use cases
- `presentation/` — screens, providers/notifiers
- `di/` — feature providers/wiring
- `test/features/<feature_name>/` — a mirrored unit test (optional)

## Usage

From repo root:

```bash
mason get
mason make feature_clean
```

Or non-interactively:

```bash
mason make feature_clean --feature_name profile --class_name Profile --include_tests true
```

Then wire the route/screen and update providers as needed. The generated
`<feature>RemoteDataSourceProvider` deliberately throws `UnimplementedError`:
override it with a real datasource before using the slice.

## Variables

| Variable | Default | Effect |
|---|---|---|
| `feature_name` | `profile` | snake_case folder name under `lib/features/` and `test/features/` |
| `class_name` | `Profile` | PascalCase prefix for the generated classes |
| `include_tests` | `true` | When `false`, **no** test file is generated — the conditional is on the file name, so no empty file is left behind |

## Guarantees

The generated slice passes this repository's own gates as-is:
`flutter analyze` reports no issues, `dart format --set-exit-if-changed` is
clean, and the generated test compiles and passes.

Two things keep that true:

- `scripts/dev/create_feature.sh`, `scripts/dev/create_feature.ps1` and this
  brick are generated from one verified source, so all three emit identical
  files. Change one, change all three.
- Doc comments are kept short on purpose. `dart format` cannot wrap a comment,
  so a doc line that embeds the class name is the one thing that can breach
  `lines_longer_than_80_chars` for an unusually long `class_name`. If you pick
  one, run `dart format lib/features/<name> test/features/<name>` and check
  `flutter analyze` before committing.
