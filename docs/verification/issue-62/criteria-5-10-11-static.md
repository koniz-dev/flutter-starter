# Criteria 5, 10, 11 - static and build-confirmed checks

## Criterion 5 - `ios/ExportOptions.plist` uses the project's real bundle ID

```console
$ plutil -p ios/ExportOptions.plist | grep -A2 provisioningProfiles
  "provisioningProfiles" => {
    "com.example.flutterStarter" => "YOUR_PROVISIONING_PROFILE_NAME"
  }

$ grep -n 'PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter;' ios/Runner.xcodeproj/project.pbxproj
374:				PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter;
554:				PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter;
577:				PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter;
```

The key was `com.example.flutter_starter`, which matches nothing in the project.
`ios/fastlane/Appfile` already used `com.example.flutterStarter`, so the plist
was the odd one out. `teamID` is still the `YOUR_TEAM_ID` placeholder by design -
it is per-adopter, and the criterion asks only for the bundle ID.

## Criterion 10 - deployment targets match the pinned Flutter

```console
$ flutter --version
Flutter 3.47.0 - channel stable

$ grep -h IPHONEOS_DEPLOYMENT_TARGET \
    /usr/local/share/flutter/packages/flutter_tools/templates/app/ios.tmpl/Runner.xcodeproj/project.pbxproj.tmpl
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
$ grep -h MACOSX_DEPLOYMENT_TARGET \
    /usr/local/share/flutter/packages/flutter_tools/templates/app/macos.tmpl/Runner.xcodeproj/project.pbxproj.tmpl
				MACOSX_DEPLOYMENT_TARGET = 12.0;
$ cat /usr/local/share/flutter/packages/flutter_tools/templates/cocoapods/Podfile-macos | head -1
platform :osx, '12.0'
```

The project was at iOS 13.0 and macOS 10.15 - the macOS app target was two
majors below the `platform :osx, '12.0'` its own generated Podfile declared for
the pods it links. Both are now at the template minimum (3 occurrences each).

Not asserted - built:

- `flutter build ios --no-codesign` -> `Built build/ios/iphoneos/Runner.app (26.0MB)` at `IPHONEOS_DEPLOYMENT_TARGET = 15.0`.
- `flutter build macos --release` -> `Built build/macos/Build/Products/Release/flutter_starter.app (50.0MB)` at `MACOSX_DEPLOYMENT_TARGET = 12.0`.

## Criterion 11 - Podfiles tracked, signing material ignored

`ios/Podfile` and `macos/Podfile` are now committed rather than regenerated-and-
hand-reverted on every session. `ios/Podfile` additionally pins
`platform :ios, '15.0'` (the Flutter template ships that line commented out);
`macos/Podfile` already carried `platform :osx, '12.0'`. `Podfile.lock` for both
platforms is committed too, which is what actually pins pod versions across
machines. `Pods/` stays ignored via `ios/.gitignore` and `macos/.gitignore`.

New `.gitignore` entries for signing material - `android/.gitignore` already
covered `key.properties`, `*.keystore` and `*.jks` for the Android side, but
nothing covered the Apple side, and `deploy-ios.yml:100` writes
`certificate.p12` into the **repository root**:

```
*.p12
*.p8
*.mobileprovision
*.provisionprofile
*.cer
*.certSigningRequest
*.keystore
*.jks
```

Plus fastlane's per-run artifacts (`report.xml`, `Preview.html`,
`screenshots/`, `test_output/`, and the `ios/fastlane/README.md` fastlane
regenerates), which this issue's own lane runs produced.
