# 🚀 Flutter Starter

A highly modular, production-ready Flutter starter framework focusing on **Clean Architecture**, optional hardening (RASP), robust environment configuration, and extensive developer tooling.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.8+-0175C2?logo=dart)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/architecture-Clean%20Architecture-blue)](docs/architecture/)

---

## 🌟 Key Highlights

- 🏛️ **Clean Architecture:** Domain, Data, Presentation layers powered by `Riverpod` and `Freezed`.
- 🛡️ **RASP (optional):** `freerasp` is in `pubspec.yaml`; the app defaults to a **no-op** `raspServiceProvider` until you wire a real implementation. See [Security implementation](docs/guides/security/implementation.md).
- 🌐 **Network Protocol:** Resilient HTTP Client (`dio`) with intercepts and a detached WebSocket Real-Time Interface.
- 🧪 **Comprehensive Automation:** Unit/widget/integration tests, optional E2E with **Patrol** (local or [manual CI workflow](.github/workflows/e2e-android.yml)).
- 🎨 **1-Click Branding:** Native splash screens and launcher icons scaffolded straight from `logo.png`.
- ⚙️ **Powerful Configurations:** Layered Fallback configurations allowing Local `.env`, `remote-configs`, and `dart-defines` overrides.

> Looking for the complete list of features and tech-stack? Check out the [**Comprehensive Documentation**](docs/README.md).

---

## Super starter (fork and customize)

- **[Super starter hub](docs/architecture/super-starter-hub.md)** — capability map and links
- **[Choose your stack](docs/architecture/choose-your-stack.md)** — keep defaults vs swap adapters
- **[Fork and customize](docs/guides/onboarding/fork-and-customize.md)** — rename package, Android/iOS ids, optional strip
- **[Repository layout](docs/guides/onboarding/repository-layout.md)** — non-platform folders (`lib`, `test`, `docs`, `scripts`, …)

### Mason brick (optional)

With [Mason CLI](https://pub.dev/packages/mason_cli) installed:

```bash
dart pub global activate mason_cli
mason get
mason make flutter_starter_setup
```

#### Demo (GIF/video)

If you want the README to feel “hands-on”, add a short demo clip showing feature generation.

- **Suggested asset path**: `docs/assets/mason-generate-feature.gif`
- **Suggested flow**:
  - `mason get`
  - `mason make feature_clean` (or your feature brick)
  - quick peek at generated folders under `lib/features/<feature>/`

Recording checklist: `docs/guides/support/mason-demo-script.md`.

After recording, reference it here:

```md
![Mason demo](docs/assets/mason-generate-feature.gif)
```

See [bricks/README.md](bricks/README.md) and [bricks/flutter_starter_setup/README.md](bricks/flutter_starter_setup/README.md). If you rename everything by hand and do not need Mason, you can remove **`bricks/`** and **`mason.yaml`**. To drop sample `tasks` and `feature_flags` without Mason: `dart run tool/strip_sample_features.dart --apply`.

---

## 🚀 Quick Start

### 1. Installation

Clone the repository and install dependencies:
```bash
git clone <repository-url> my_app
cd my_app
flutter pub get
```

### 2. Generate Boilerplate Code
Run the build runner to generate Riverpod providers, JSON serialization, and Freezed unions:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Native Branding (Optional)
Drop an image to `assets/images/logo.png` and auto-generate Android and iOS splash screens/icons via:
```bash
./scripts/dev/setup_branding.sh
```

### 4. Application Configuration
Initialize the local environment settings explicitly:
```bash
cp .env.example .env
```
_(Open `.env` and fill out backend specifics before compiling)_

### 5. Running
```bash
flutter run
```

### 6. E2E tests (Patrol, optional)

Patrol does not run on every PR by default. Locally: `dart pub global activate patrol_cli` then `./scripts/test/run_e2e_tests.sh` (or `patrol test --target integration_test/app_e2e_test.dart`). On GitHub: **Actions → E2E Android (Patrol) → Run workflow** (Android emulator). Stable selectors use [`lib/core/constants/ui_keys.dart`](lib/core/constants/ui_keys.dart).

---

## 📚 Central Documentation

Rather than cluttering this repository root, we've broken down every system behavior into dedicated guides. Start exploring:

*   📖 **[Documentation Home (Overview & Modules)](docs/README.md)** 
*   🏛️ **[Architecture Decisions (Clean Architecture & Layers)](docs/architecture/README.md)**
*   ⚙️ **[Configuration & Environment Overrides](docs/guides/configuration.md)**
*   🌐 **[Network & Real-Time Websockets APIs](docs/api/core/network.md)**
*   🛡️ **[Security, Anti-Tamper & RASP Implementation](docs/guides/security/implementation.md)**
*   🧪 **[Testing & Automated Coverage Checks](docs/guides/testing/testing-summary.md)**
*   🚀 **[Deployment (stores & CI)](docs/deployment/README.md)**
*   🆕 **[Creating New Features](docs/api/examples/adding-features.md)**

---

## 🤝 Contributing & License

We adhere to standard Conventional Commits and GitHooks to ensure clean delivery. Please review the [**Contributing Guide**](CONTRIBUTING.md) to learn how to open Pull Requests properly.

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
**Made with ❤️ using Flutter**
