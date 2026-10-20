# Criterion 4 - fastlane, the parts that are not a lane run

`criterion-4-fastlane-lanes.log` is the executed half: six credential-free lanes
across both platforms, all exit 0, with fastlane 2.240.1 installed locally.
The build and upload lanes need an Android SDK / Xcode signing identity that
this machine does not have; they are routed to `status:needs-uat`.

What the log proves, quoting it:

| Line | What it shows |
| --- | --- |
| `cd ios/fastlane && fastlane ios version` -> `Version: 1.0.0, Build: 1` | `File.read("../../pubspec.yaml")` resolves. Before this change the path was `../pubspec.yaml` = `ios/pubspec.yaml`, which does not exist, so **every** iOS lane died in `get_version`. |
| `cd fastlane && fastlane android version` -> `Version: 1.0.0, Version Code: 1` | the root Fastfile's `../pubspec.yaml` still resolves; the two files use different conventions on purpose. |
| `fastlane ios update_changelog` -> `Changelog exists at: ../../fastlane/metadata/android/en-US/changelogs/default.txt` | the iOS changelog path resolves. |
| `fastlane android update_changelog` -> `Changelog exists at: ../fastlane/metadata/android/en-US/changelogs/default.txt` | the root one did **not** before: it read `fastlane/metadata/...` relative to `fastlane/`, i.e. `fastlane/fastlane/metadata/...`. |
| every `--- exit: 0 ---` | no lane raises. The first run of `fastlane ios version` on this branch failed with `LocalJumpError` from `return` inside a lane block; see below. |

## Defects fixed that the lane run cannot reach

`--flavor` is gone. The project declares no product flavors
(`grep -c 'productFlavors\|flavorDimensions' android/app/build.gradle.kts` -> 0,
removed in #34), so `--flavor production` failed with
`Task 'assembleProductionRelease' not found`.

```console
$ grep -rn 'flavor' fastlane/Fastfile ios/fastlane/Fastfile | grep -v ': *#'
(no output - the four remaining hits are all comment lines)
```

Artifact paths now match the flavorless layout Flutter actually writes:

| Lane | Before | After |
| --- | --- | --- |
| `build_bundle` | `build/app/outputs/bundle/productionRelease/app-production-release.aab` | `build/app/outputs/bundle/release/app-release.aab` |
| `build_apk` | `build/app/outputs/flutter-apk/app-production-release.apk` | `build/app/outputs/flutter-apk/app-release.apk` |

`base_url` and `environment` are shell-escaped with `Shellwords.escape` before
interpolation into the `sh(...)` string, in all four build lanes.

`skip_screenshots` is honoured. `options[:skip_screenshots] || true` can never be
false; it is now `options.fetch(:skip_screenshots, true)`. Same for
`skip_metadata`.

`build_adhoc` passes `--export-method ad-hoc`. Without it `flutter build ipa`
defaults to `app-store`, which is not installable on ad-hoc devices:

```console
$ flutter build ipa --help
    --export-method     Specify how the IPA will be distributed.
          [app-store] (default)   Upload to the App Store.
          [ad-hoc]                Test on designated devices ...
```

## Found while driving this, and fixed here

`return` inside a lane body raises `LocalJumpError` - a lane is a block, not a
method. This was pre-existing in both Fastfiles and it broke **every** lane that
called `get_version`, `build_bundle`, `build_apk`, `build_appstore` or
`build_adhoc`, which is all of them. First observed output on this branch before
the fix:

```
[20:23:26]: Cruising over to lane 'ios get_version'
[20:23:26]: Version: 1.0.0, Build: 1
[20:23:26]: Error in your Fastfile at line 40
    38:       build_number = version_match[2]
    39:       UI.message("Version: #{version_name}, Build: #{build_number}")
 => 40:       return { version: version_name, build: build_number }
[20:23:26]: fastlane finished with errors
```

Note it printed the version first: the path fix had already worked, and the
`return` was the next wall behind it. Both Fastfiles now end their helper lanes
on a bare expression.

Ruby parses both files:

```console
$ ruby -c fastlane/Fastfile && ruby -c ios/fastlane/Fastfile
Syntax OK
Syntax OK
```
