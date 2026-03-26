# 🚀 Flutter Starter

A highly modular, production-ready Flutter starter framework focusing on **Clean Architecture**, security compliance (RASP), robust environment configurations, and extensive developer tooling.

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/architecture-Clean%20Architecture-blue)](docs/architecture/)

---

## 🌟 Key Highlights

- 🏛️ **Clean Architecture:** Domain, Data, Presentation layers powered by `Riverpod` and `Freezed`.
- 🛡️ **Enterprise Security (RASP):** Real-time monitoring against Jailbreak, Debugging, and Tampering (`freerasp`).
- 🌐 **Network Protocol:** Resilient HTTP Client (`dio`) with intercepts and a detached WebSocket Real-Time Interface.
- 🧪 **Comprehensive Automation:** End-to-End (`patrol`), UI/Unit Testing covering all core layers.
- 🎨 **1-Click Branding:** Native splash screens and launcher icons scaffolded straight from `logo.png`.
- ⚙️ **Powerful Configurations:** Layered Fallback configurations allowing Local `.env`, `remote-configs`, and `dart-defines` overrides.

> Looking for the complete list of features and tech-stack? Check out the [**Comprehensive Documentation**](docs/README.md).

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

---

## 📚 Central Documentation

Rather than cluttering this repository root, we've broken down every system behavior into dedicated guides. Start exploring:

*   📖 **[Documentation Home (Overview & Modules)](docs/README.md)** 
*   🏛️ **[Architecture Decisions (Clean Architecture & Layers)](docs/architecture/README.md)**
*   ⚙️ **[Configuration & Environment Overrides](docs/guides/configuration.md)**
*   🌐 **[Network & Real-Time Websockets APIs](docs/api/core/network.md)**
*   🛡️ **[Security, Anti-Tamper & RASP Implementation](docs/guides/security/implementation.md)**
*   🧪 **[Testing & Automated Coverage Checks](docs/guides/testing/testing-summary.md)**
*   🚀 **[Deployment, App Stores & Git Triggers](docs/deployment/deployment.md)**
*   🆕 **[Creating New Features via CLI Scaffold](docs/api/examples/adding-features.md)**

---

## 🤝 Contributing & License

We adhere to standard Conventional Commits and GitHooks to ensure clean delivery. Please review the [**Contributing Guide**](CONTRIBUTING.md) to learn how to open Pull Requests properly.

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
**Made with ❤️ using Flutter**
