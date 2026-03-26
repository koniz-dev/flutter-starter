# Automation Tooling Overview

This documentation outlines the automated scripts added in the latest Enterprise Update for Scaffold Branding and CI workflow injections.

## 🎨 1. App Branding Engine

Instead of manually crafting Android Adaptive Icons, iOS App Icons, and Splash Screens in `xml` and Xcode `Storyboards`, you can seamlessly generate them.

### Input Requirement:
Store your main 1024x1024 app logo at: `assets/images/logo.png`.

### Command:
```bash
./scripts/dev/setup_branding.sh
```

### What it does:
- Runs `flutter_native_splash:create` to bake your logo onto the native startup screen.
- Runs `flutter_launcher_icons` to slice your logo into all required pixel resolutions for Android (`res/mipmap`) and iOS (`Assets.xcassets`).
- Triggers a clean workflow, making sure your new brand imagery links perfectly into the app binary.

---

## ⚙️ 2. CI/CD Initializer

The flutter_starter project includes GitHub Actions workflows housed inside `.github/workflows/`. By default, the `on: push` and `on: pull_request` triggers are intentionally commented out to prevent spam builds on your repository if you're not ready.

### Command:
```bash
dart scripts/dev/setup_ci.dart
```

### What it does:
- It launches an interactive Dart CLI asking if you want to activate the CI pipelines.
- Automatically removes `##` prefixes in `ci.yml` and `build.yml`.
- Pushes structural changes efficiently freeing your time from manual Yaml edits.
