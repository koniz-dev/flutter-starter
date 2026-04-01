# Flutter Starter Documentation

Welcome to the documentation for the Flutter starter template. The template is organized around **Clean Architecture**, explicit boundaries, and replaceable integrations.

## Super starter entry

Start here when adopting or forking the template:

- [**Super starter hub**](architecture/super-starter-hub.md) — capability matrix and links to every area
- [**Choose your stack**](architecture/choose-your-stack.md) — Path A (defaults) vs Path B (bring your own adapters)
- [**Contracts and adapter map**](architecture/contracts-map.md) — swap points and optional modules
- [**Fork and customize**](guides/onboarding/fork-and-customize.md) — rename package, Mason, optional strip
- [**Repository layout (non-platform)**](guides/onboarding/repository-layout.md) — `lib`, `test`, `docs`, `scripts`, CI, bricks

Root [README.md](../README.md) also links Mason and these docs.

## Canonical code paths (for writers)

Keep docs and examples pointing here unless the tree moves:

| Topic | Path |
|--------|------|
| Bootstrap / scope | `lib/main.dart`, `lib/core/di/providers.dart` |
| Routes | `lib/core/routing/app_router.dart`, `lib/core/routing/navigation_providers.dart` |
| Network | `lib/core/network/api_client.dart`, `lib/core/network/interceptors/` |
| Performance | `lib/core/performance/`, [`examples/performance_examples.dart`](../examples/performance_examples.dart) |
| RASP | `lib/core/security/rasp_providers.dart`, `lib/core/security/infrastructure/freerasp_service_impl.dart` |
| Security (optional templates) | [`guides/security/blueprints.md`](guides/security/blueprints.md) |

## Documentation vs code (drift)

- **Workflows:** [Testing summary](guides/testing/testing-summary.md) matches [`.github/workflows/`](../.github/workflows/); if you change CI, update that guide.
- **`docs/api/`:** Describes `lib/` APIs — after refactors, search for old file paths or class names here.
- **Fork renames:** Mason does not rewrite Markdown; samples may still show `package:flutter_starter` until you replace them ([Fork and customize](guides/onboarding/fork-and-customize.md)).
- **Blueprints:** Long-form guides (especially [Security implementation](guides/security/implementation.md)) mix edits to existing files with **optional** modules you add yourself; headings mark blueprints where relevant.
- **`examples/`:** [`examples/`](../examples/) — see [`examples/README.md`](../examples/README.md); also [Repository layout](guides/onboarding/repository-layout.md).

## 📚 General Documentation Map

Navigate through the folders to dive deeper into the project modules:

- 🏛️ [**Architecture**](architecture/README.md) - Boundaries, contracts, adapters, and migration strategy.
- 📖 [**Guides**](guides/onboarding/getting-started.md) - Onboarding and practical implementation guides.
- 🧰 [**Troubleshooting**](guides/support/troubleshooting.md) - Common setup/build/test issues and quick fixes.
- 🚀 [**Deployment**](deployment/README.md) - Store releases, Fastlane, and GitHub Actions deploy workflows.
- 🛡️ [**Security**](guides/security/README.md) - Security baseline, checklist, and implementation notes.
- ⚙️ [**Configuration**](guides/configuration.md) - `.env` and `--dart-define` setup.
- 🎨 [**Design System**](architecture/adr/0004-theme-token-boundary.md) - Semantic token contract and theme mapping.
- 💻 [**API Specs**](api/README.md) - Core and feature API references.

---

## Starter Principles
### Architecture and Quality
- ✅ **Clean Architecture** - Domain/data/presentation separation
- ✅ **Explicit Boundaries** - Contracts in `core/contracts` + adapters
- ✅ **State Management** - Riverpod with controller boundary contracts
- ✅ **Code Quality** - Strict linting and test-first migration flow

### Security and Storage
- ✅ **Optional RASP** - No-op by default, FreeRASP via override
- ✅ **Token Boundary** - `ITokenStore` abstraction for sensitive secrets
- ✅ **Storage Boundary** - `IKeyValueStore` and adapters

### Networking
- ✅ **Transport Contract** - `INetworkClient` + `NetworkRequest/Response/Error`
- ✅ **Dio façade** - `ApiClient` exposes Dio + interceptors and delegates to `DioNetworkClient`
- ✅ **Typed DI** - `apiClientProvider` and `networkClientProvider` (same `ApiClient` instance)

### Testing and DX
- ✅ **Unit/Widget Coverage** - Core and feature behavior tests
- ✅ **Template Modules** - GraphQL, Crashlytics output, and Isar templates
- ✅ **Design Tokens** - Shared source of truth for app theme and Widgetbook

---

## Core vs Optional Modules

### Hard-Core (fixed by default starter architecture)
- **State + DI:** Riverpod provider architecture and app bootstrap flow.
- **Routing:** GoRouter-based route tree and guards.
- **HTTP Layer:** Dio-based `ApiClient` and interceptor pipeline.

### Optional / Pluggable (safe to replace or skip)
- **Feature Flags Remote:** Firebase Remote Config integration is optional; default flow can run with local/no-op remote flags.
- **RASP:** FreeRASP implementation is opt-in via provider override.
- **Performance Monitoring:** Default uses no-op performance service; Firebase performance is opt-in.
- **Firebase setup:** Firebase dependencies are intentionally not present in `pubspec.yaml` by default; opt in by adding packages and wiring the optional templates/providers in docs.
- **Crashlytics Logging Output:** Template-only and opt-in.
- **GraphQL Client:** Template-only and opt-in.
- **Advanced Local DB (Isar):** Interface + template; optional.

---

## 🛠️ Tech Stack

### Core Dependencies
- **Flutter** - UI framework
- **Riverpod** - State management
- **Dio** / **web_socket_channel** - Network client & WebSockets
- **Freezed** & **Equatable** - Data models and code-generation

### Security & Storage
- **freerasp** - RASP engine
- **flutter_secure_storage** - Encrypted key-values
- **shared_preferences** - Simple key-value mapping

### Development Tools
- **patrol** - End-to-end (E2E) UI testing
- **mocktail** - Testing and mocking
- **flutter_launcher_icons** & **flutter_native_splash** - Automated Icon & Splash rendering
- **very_good_analysis** - Strict Lint rules

---

## Project Structure

Top-level folders outside `lib/`:

- **`tool/`** — One-off maintenance scripts (for example `strip_sample_features.dart`); not shipped with the app.
- **`bricks/`** — Mason brick(s) for rename / optional strip; not app runtime code. Index: [bricks/README.md](../bricks/README.md).
- **`test/`** — Unit, widget, and integration tests (mirrors `lib/` where it helps).

```
lib/
├── core/                    # Core infrastructure
│   ├── config/             # Configuration system (env layers, flags)
│   ├── constants/          # App constants
│   ├── di/                 # Dependency injection (Global Riverpod providers)
│   ├── errors/             # Error handling
│   ├── localization/       # Localization service
│   ├── logging/            # Logging service
│   ├── network/            # HTTP Client and Websocket realtime connection
│   ├── performance/        # Performance monitoring (Decoupled interface)
│   ├── routing/            # App routes, router, navigation adapters
│   ├── security/           # RASP Security Module
│   ├── storage/            # Storage contracts, adapters, and services
│   └── utils/              # Generic utilities
│
├── features/                # Clean Architecture feature modules
│   ├── auth/               # Example: Authentication feature
│   ├── feature_flags/      # Example: Dynamic Flag Toggle UI
│   └── tasks/              # Example: Standard CRUD operation
│
├── shared/                  # Agnostic reusable resources
│   ├── accessibility/      # A11y helpers
│   ├── design_system/      # Design tokens and widgetbook templates
│   ├── extensions/         # Dart type extensions
│   ├── theme/              # App theme built from semantic tokens
│   └── widgets/            # Generic custom widgets
│
├── l10n/                   # Language `.arb` files
└── main.dart               # Bootstrap entry point
```
