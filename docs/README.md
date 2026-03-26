# Flutter Starter Documentation

Welcome to the comprehensive documentation for the Flutter Enterprise Starter project. This repository is built on Solid **Clean Architecture**, scalable configurations, and enterprise-grade utilities.

## 📚 General Documentation Map

Navigate through the folders to dive deeper into the project modules:

- 🏛️ [**Architecture**](architecture/README.md) - Understanding Clean Architecture, presentation, domain, and data layers.
- 📖 [**Guides**](guides/getting-started.md) - Practical step-by-step guides for onboarding, routing, localization, configuration, performance, and testing.
- 🛡️ [**Security**](guides/security/implementation.md) - RASP module, FreeRASP implementation, Certificate Pinning.
- ⚙️ [**Configuration System**](guides/configuration.md) - Using `.env` and `dart-defines` safely.
- 🚀 [**Deployment & CI/CD**](deployment/deployment.md) - CI/CD pipelines, Native Branding generation, Fastlane.
- 💻 [**API Specifications**](api/README.md) - In-depth breakdown of `ApiClient`, WebSockets (`IRealtimeClient`), loggers, and storage.

---

## ✨ Enterprise Features Breakdown
### 🏗️ Architecture & Code Quality
- ✅ **Clean Architecture** - Separation of concerns with Domain, Data, and Presentation layers
- ✅ **State Management** - Riverpod for reactive state management
- ✅ **Code Generation** - Freezed for immutable classes and JSON serialization
- ✅ **Linting** - Very Good Analysis for comprehensive code quality checks

### 🔐 Security & Storage
- ✅ **RASP Security** - FreeRASP integration to prevent tampering, debuggers, and emulators
- ✅ **Secure Storage** - Flutter Secure Storage for sensitive data
- ✅ **Storage Migration** - Version-based storage migration system

### 🌐 Network Layer
- ✅ **HTTP Client** - Dio with interceptors support
- ✅ **Real-time WebSockets** - Decoupled `IRealtimeClient` using `web_socket_channel`
- ✅ **Auth Interceptors** - Automatic token injection and refresh

### 🚀 Deployment & CI/CD
- ✅ **Native Branding** - 1-click App Icon and Splash screen scaffold via `setup_branding.sh`
- ✅ **CI/CD Ready** - GitHub Actions workflows & interactive activation loop (`setup_ci.dart`)
- ✅ **Fastlane Integration** - iOS and Android deployment automation

### 🧪 Testing
- ✅ **66+ Test Files** - Unit, Widget, and Integration coverage.
- ✅ **E2E Automation** - UI-driven testing via Patrol (`auth_flow_test.dart`)

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

## 📁 Complete Project Structure

```
lib/
├── core/                    # Core infrastructure
│   ├── config/             # Configuration system (env layers, flags)
│   ├── constants/          # App constants
│   ├── di/                 # Dependency injection (Global Riverpod providers)
│   ├── errors/             # Error handling
│   ├── feature_flags/      # Feature flags infrastructure
│   ├── localization/       # Localization service
│   ├── logging/            # Logging service
│   ├── network/            # HTTP Client and Websocket realtime connection
│   ├── performance/        # Performance monitoring (Decoupled interface)
│   ├── routing/            # GoRouter configuration
│   ├── security/           # RASP Security Module
│   ├── storage/            # Platform-agnostic storage services
│   └── utils/              # Generic utilities
│
├── features/                # Clean Architecture feature modules
│   ├── auth/               # Example: Authentication feature
│   ├── feature_flags/      # Example: Dynamic Flag Toggle UI
│   └── tasks/              # Example: Standard CRUD operation
│
├── shared/                  # Agnostic reusable resources
│   ├── accessibility/      # A11y helpers
│   ├── extensions/         # Dart type extensions
│   ├── theme/              # FlexColor themes
│   └── widgets/            # Generic custom widgets
│
├── l10n/                   # Language `.arb` files
└── main.dart               # Bootstrap entry point
```
