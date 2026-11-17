### v4 to v5 (starter v5.0.0)

The [v5.0.0 release notes](https://github.com/koniz-dev/flutter-starter/releases/tag/v5.0.0)
list every breaking change with what it asks of you. Three of them need more
than copying the changed files:

1. **Add the standalone UI packages.** Material and Cupertino widgets now come
   from `material_ui` and `cupertino_ui`, which are new dependencies, not
   version bumps: `flutter pub get` does not add them. Add both to
   `pubspec.yaml`, then switch your imports as described under
   [Standalone UI libraries](#standalone-ui-libraries-on-flutter-350):

   ```yaml
   dependencies:
     cupertino_ui: ^1.1.6
     material_ui: ^1.11.0
   ```

2. **Move iOS to the UIScene lifecycle - both halves.** `ios/Runner/AppDelegate.swift`
   conforms to `FlutterImplicitEngineDelegate` and registers plugins in
   `didInitializeImplicitFlutterEngine`, and `ios/Runner/Info.plist` gains a
   `UIApplicationSceneManifest` entry whose scene delegate is
   `FlutterSceneDelegate`. If you have a custom `AppDelegate`, carry your code
   into the new shape **and** copy the `UIApplicationSceneManifest` block from
   the starter's `Info.plist`; the AppDelegate change alone is incomplete. See
   [iOS deployment](../../deployment/ios-deployment.md).
3. **Give release builds an API URL.** `scripts/ci/build_all.sh` and the
   manual `build.yml` refuse a staging or production build without
   `BASE_URL_STAGING` / `BASE_URL_PRODUCTION` (or `build.yml`'s `base_url`
   input); there is no `api.example.com` fallback any more.

#### Standalone UI libraries on Flutter 3.50

The starter imports Material widgets from `package:material_ui/material_ui.dart`
and Cupertino widgets from `package:cupertino_ui/cupertino_ui.dart`. Both are
explicit dependencies. Update custom widgets, theme extensions and design-token
implementations to use the same imports: SDK and standalone `ThemeData`,
`ColorScheme` and other design-library types have different identities.

Keep using `AppLocalizations.delegate` for application strings. For a standalone
`MaterialApp`, add `...GlobalMaterialLocalizations.delegates` from `material_ui`;
this includes the matching Material, Cupertino and framework widget delegates.
The starter configures the SDK generator through the `header` in `l10n.yaml`.
It binds the generated global-delegate names to the two standalone delegate
adapters in `lib/core/localization/`, so
`AppLocalizations.localizationsDelegates` also supplies the correct UI types.
Keep this header when regenerating translations with `flutter gen-l10n`; do not
edit the generated files. Its relative imports survive package renaming. If you
move the generated output directory, update those paths too.

An explicit delegate list works as well:

```dart
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

const delegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
```

Check third-party UI packages during migration. A legacy widget that reads the
old Material theme/localizations may need the temporary compatibility bridge in
`MaterialApp.builder`; a bridge does not convert public API argument types.
See the [Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui)
for package interoperability details. The starter does not install a bridge for
widgets that do not need one.

