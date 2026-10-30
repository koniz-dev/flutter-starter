// The Android build opts out of AGP 9's built-in Kotlin exactly as long as a
// resolved plugin still applies the Kotlin Gradle plugin (KGP) itself.
//
// The opt-out (`android.builtInKotlin=false`, `android.newDsl=false`) is what
// `flutter create` writes today, and it cannot go while patrol or
// shared_preferences_android apply `kotlin-android`. Plugin versions are fixed
// by pubspec.lock, so the moment that stops being true is the PR that bumps
// them. This fails there, with the recipe, instead of leaving the opt-out to
// outlive its reason until AGP removes the flags and the build breaks.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _appliesKgp = RegExp(
  r'''kotlin-android|org\.jetbrains\.kotlin\.android|kotlin\(\s*["']android["']\s*\)''',
);

/// The names of [buildFiles] (plugin name -> android build script source)
/// whose script applies the Kotlin Gradle plugin.
Set<String> pluginsApplyingKgp(Map<String, String> buildFiles) => {
  for (final MapEntry(key: name, value: source) in buildFiles.entries)
    if (_appliesKgp.hasMatch(source)) name,
};

/// Whether `android/gradle.properties` [source] opts out of built-in Kotlin.
bool optsOut(String source) => RegExp(
  r'^\s*android\.builtInKotlin\s*=\s*false\s*$',
  multiLine: true,
).hasMatch(source);

/// Why the opt-out and the resolved plugins disagree, or null when they agree.
String? mismatch({required bool optedOut, required Set<String> kgpPlugins}) {
  if (optedOut && kgpPlugins.isEmpty) {
    return 'No resolved plugin applies the Kotlin Gradle plugin any more, so '
        'the built-in Kotlin opt-out has outlived its reason. Migrate now: '
        'remove id("kotlin-android") from android/app/build.gradle.kts and '
        'android.builtInKotlin / android.newDsl from android/gradle.properties '
        '(https://docs.flutter.dev/release/breaking-changes/'
        'migrate-to-built-in-kotlin/for-app-developers).';
  }
  if (!optedOut && kgpPlugins.isNotEmpty) {
    return 'android/gradle.properties no longer opts out of built-in Kotlin, '
        'but these resolved plugins still apply the Kotlin Gradle plugin: '
        '${(kgpPlugins.toList()..sort()).join(', ')}. Keep '
        'android.builtInKotlin=false and android.newDsl=false until they ship '
        'built-in-Kotlin versions.';
  }
  return null;
}

/// Plugin name -> android build script, for every resolved package that has
/// one, read through `.dart_tool/package_config.json`.
Map<String, String> _resolvedAndroidBuildFiles() {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final files = <String, String>{};
  for (final package
      in (config['packages'] as List).cast<Map<String, dynamic>>()) {
    final uri = Uri.parse(package['rootUri'] as String);
    if (!uri.isAbsolute) continue; // this package itself
    final root = uri.toFilePath();
    for (final name in ['build.gradle', 'build.gradle.kts']) {
      final script = File('$root/android/$name');
      if (script.existsSync()) {
        files[package['name'] as String] = script.readAsStringSync();
      }
    }
  }
  return files;
}

void main() {
  test(
    'criterion 2: the opt-out lasts exactly as long as a plugin applies KGP',
    () {
      final kgp = pluginsApplyingKgp(_resolvedAndroidBuildFiles());
      final optedOut = optsOut(
        File('android/gradle.properties').readAsStringSync(),
      );

      final problem = mismatch(optedOut: optedOut, kgpPlugins: kgp);
      expect(problem, isNull, reason: problem);
    },
  );

  group('criterion 2: both directions fail', () {
    test('opted out, but no resolved plugin applies KGP: migrate now', () {
      final problem = mismatch(optedOut: true, kgpPlugins: const {});
      expect(problem, contains('Migrate now'));
    });

    test('opt-out removed while a plugin still applies KGP', () {
      final problem = mismatch(optedOut: false, kgpPlugins: const {'patrol'});
      expect(problem, contains('patrol'));
    });

    test('agreement either way passes', () {
      expect(mismatch(optedOut: true, kgpPlugins: const {'patrol'}), isNull);
      expect(mismatch(optedOut: false, kgpPlugins: const {}), isNull);
    });
  });

  group('detection', () {
    test('recognises each way a build script applies KGP', () {
      expect(
        pluginsApplyingKgp({
          'a': "apply plugin: 'kotlin-android'",
          'b': 'plugins { id("org.jetbrains.kotlin.android") }',
          'c': 'plugins { kotlin("android") }',
          'd': "apply plugin: 'com.android.library'",
        }),
        {'a', 'b', 'c'},
      );
    });

    test('reads the flag only as a real, uncommented assignment', () {
      expect(optsOut('android.builtInKotlin=false\n'), isTrue);
      expect(optsOut('# android.builtInKotlin=false\n'), isFalse);
      expect(optsOut('android.builtInKotlin=true\n'), isFalse);
    });
  });
}
