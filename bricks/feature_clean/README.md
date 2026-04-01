# feature_clean

Generates a new feature module under `lib/features/<feature_name>/` following the starter's conventions:

- `data/` — datasources, models, repository implementations
- `domain/` — entities, repository contracts, use cases
- `presentation/` — screens, providers/notifiers
- `di/` — feature providers/wiring

## Usage

From repo root:

```bash
mason get
mason make feature_clean
```

Then wire the route/screen and update providers as needed.

