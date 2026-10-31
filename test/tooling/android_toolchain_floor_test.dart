// The Android toolchain floor check.
//
// Flutter only warns when Gradle, AGP or Kotlin drops below what it supports;
// `tool/check_android_toolchain.dart` turns that into a failure. These tests
// pin it on fixtures - including the Gradle 8.14 the project once sat on -
// and run it over the real `android/` files.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_android_toolchain.dart';

/// A throwaway project root holding just the two files the check reads.
Directory _fixture({
  String gradle = '9.3.1',
  String agp = '9.1.0',
  String kotlin = '2.4.0',
}) {
  final root = Directory.systemTemp.createTempSync('toolchain_floor_');
  addTearDown(() => root.deleteSync(recursive: true));
  File('${root.path}/android/gradle/wrapper/gradle-wrapper.properties')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      r'distributionUrl=https\://services.gradle.org/distributions/'
      'gradle-$gradle-all.zip\n',
    );
  File('${root.path}/android/settings.gradle.kts')
    ..createSync(recursive: true)
    ..writeAsStringSync('''
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "$agp" apply false
    id("org.jetbrains.kotlin.android") version "$kotlin" apply false
}
''');
  return root;
}

void main() {
  group('compareVersions', () {
    test('orders dotted versions numerically', () {
      expect(compareVersions('8.14', '9.1.0'), lessThan(0));
      expect(compareVersions('9.10.0', '9.9.0'), greaterThan(0));
      expect(compareVersions('9.1', '9.1.0'), 0);
      expect(compareVersions('2.3.20', '2.3.3'), greaterThan(0));
      expect(compareVersions('9.1.0-rc1', '9.1.0'), 0);
    });
  });

  test('criterion 2: fails on a fixture with gradle-8.14, naming it', () {
    final problems = androidToolchainProblems(_fixture(gradle: '8.14'));

    expect(problems, hasLength(1));
    expect(problems.single, startsWith('Gradle 8.14 is below the floor 9.1.0'));
  });

  test('fails on AGP and Kotlin below their floors, one message each', () {
    final problems = androidToolchainProblems(
      _fixture(agp: '8.11.1', kotlin: '2.2.20'),
    );

    expect(problems, [
      startsWith('Android Gradle Plugin 8.11.1 is below the floor 9.0.1'),
      startsWith('Kotlin 2.2.20 is below the floor 2.3.20'),
    ]);
  });

  test('a version exactly at the floor passes', () {
    expect(
      androidToolchainProblems(
        _fixture(gradle: '9.1.0', agp: '9.0.1', kotlin: '2.3.20'),
      ),
      isEmpty,
    );
  });

  test('an unreadable version is a problem, not a pass', () {
    final root = _fixture();
    File('${root.path}/android/settings.gradle.kts').writeAsStringSync('');

    expect(androidToolchainProblems(root), [
      'Android Gradle Plugin: version not found in android/settings.gradle.kts',
      'Kotlin: version not found in android/settings.gradle.kts',
    ]);
  });

  test('a commented-out version is ignored for the live one', () {
    final root = Directory.systemTemp.createTempSync('toolchain_comment_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/android/gradle/wrapper/gradle-wrapper.properties')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        [
          r'! distributionUrl=https\://services.gradle.org/distributions/gradle-98.0-all.zip',
          r'# distributionUrl=https\://services.gradle.org/distributions/gradle-99.0-all.zip',
          r'distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-all.zip',
          '',
        ].join('\n'),
      );
    File('${root.path}/android/settings.gradle.kts')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
val libs = fileTree("libs") { include("**/*.jar") } // a `/*` in a string
plugins {
    /* outer /* nested */
    id("com.android.application") version "97.0.0" apply false
    */
    /*
    id("com.android.application") version "98.0.0" apply false
    id("org.jetbrains.kotlin.android") version "98.0.0" apply false
    */
    // id("com.android.application") version "99.0.0" apply false
    id("com.android.application") version "8.1.0" apply false
    // id("org.jetbrains.kotlin.android") version "99.0.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
}
val out = "build/**/" // closes nothing: the `/*` above was in a string
''');

    expect(readAndroidToolchain(root), {
      'Gradle': '8.14',
      'Android Gradle Plugin': '8.1.0',
      'Kotlin': '1.9.0',
    });
  });

  test('criterion 2: passes on the real android/ files', () {
    final found = readAndroidToolchain(Directory.current);
    expect(found.values, everyElement(isNotNull), reason: '$found');
    expect(androidToolchainProblems(Directory.current), isEmpty);
  });
}
