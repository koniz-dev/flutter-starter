# Choose your stack

This template is a **single codebase** with **fixed architectural ideas** and **replaceable implementations** behind contracts and adapters.

## Two paths

### Path A — Keep the default stack

Use what ships in the repo:

- **State + DI:** Riverpod
- **Routing:** GoRouter
- **HTTP:** Dio behind `INetworkClient` (`ApiClient` compatibility layer)
- **Storage:** `IKeyValueStore` / `ITokenStore` with secure + shared prefs adapters
- **Sample features:** `auth`, optional `tasks` and `feature_flags` modules as references

Follow [Getting started](../guides/onboarding/getting-started.md), then add features under `lib/features/<name>/` using the same layer layout.

### Path B — Bring your own stack

Keep **domain** (entities, repository interfaces, use cases) and **contracts** in `lib/core/contracts/`. Replace or wrap vendor code in **adapters** and rebind providers in the composition root (`lib/core/di/providers.dart`, feature `*_providers.dart`, `lib/main.dart`).

Do **not** import Flutter widgets, Dio, GoRouter, or Riverpod from `domain/`. If a use case needs a port, express it as an interface in domain or use an existing core contract.

## Where to look

| Topic | Document |
| --- | --- |
| Contract locations and adapters | [contracts-map.md](contracts-map.md) |
| All capabilities in one place | [super-starter-hub.md](super-starter-hub.md) |
| Architectural decisions | [adr/README.md](adr/README.md) |
| Incremental migration | [migrations/README.md](migrations/README.md) |
| Risks and verification | [migrations/quality-gates-and-risks.md](migrations/quality-gates-and-risks.md) |
| Fork, rename, optional strip | [Fork and customize](../guides/onboarding/fork-and-customize.md) |

## Out of scope for generated variants

This repository does **not** maintain parallel starters (e.g. duplicate apps for BLoC vs Riverpod). That avoids doc and code drift. Path B means **you** supply the adapter and provider bindings while keeping the same layer boundaries.
