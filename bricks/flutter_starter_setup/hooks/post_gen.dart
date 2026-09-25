import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final logger = context.logger;
  // Mason sets the process working directory to the generation output folder
  // before running hooks; HookContext has no target path API (mason ^0.1.2+).
  final rootPath = Directory.current.path;
  final packageName = context.vars['package_name'] as String;
  final applicationId = context.vars['application_id'] as String;
  final iosBundleId = context.vars['ios_bundle_id'] as String;
  final appDisplayName = context.vars['app_display_name'] as String;
  final strip = context.vars['strip_sample_features'] == true;
  final includeTasks = context.vars['include_tasks_sample'] != false;
  final includeFeatureFlags =
      context.vars['include_feature_flags_sample'] != false;

  final shouldStripAll = strip || (!includeTasks && !includeFeatureFlags);
  final shouldStripTasksOnly = !strip && !includeTasks && includeFeatureFlags;
  final shouldStripFeatureFlagsOnly =
      !strip && includeTasks && !includeFeatureFlags;

  if (shouldStripAll || shouldStripTasksOnly || shouldStripFeatureFlagsOnly) {
    logger.info('Running strip_sample_features...');
    final stripArgs = <String>[
      'run',
      'tool/strip_sample_features.dart',
      '--apply',
      if (shouldStripTasksOnly) '--tasks-only',
      if (shouldStripFeatureFlagsOnly) '--feature-flags-only',
    ];
    final result = await Process.run(
      'dart',
      stripArgs,
      workingDirectory: rootPath,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      logger.err(result.stderr.toString());
      throw Exception(
        'strip_sample_features failed with exit ${result.exitCode}',
      );
    }
  }

  await _renameDartPackage(rootPath, packageName, logger);
  await _patchAndroidGradle(rootPath, applicationId);
  await _patchAndroidManifest(rootPath, appDisplayName);
  await _relocateMainActivity(rootPath, applicationId, logger);
  await _relocateMainActivityTest(rootPath, applicationId, logger);
  await _patchIosBundleIds(rootPath, iosBundleId, logger);
  await _patchPatrolConfig(rootPath, applicationId, appDisplayName, logger);
  await _patchPlatformIdentifiers(
    rootPath: rootPath,
    packageName: packageName,
    applicationId: applicationId,
    iosBundleId: iosBundleId,
    appDisplayName: appDisplayName,
    logger: logger,
  );

  logger.alert(
    'Setup complete. Next: flutter pub get && flutter analyze && flutter test',
  );
}

Future<void> _renameDartPackage(
  String rootPath,
  String packageName,
  Logger logger,
) async {
  const oldImport = 'package:flutter_starter/';
  final newImport = 'package:$packageName/';
  // `examples/` is analysed and formatted with the rest (see CLAUDE.md), and
  // `.dart.template` files are real sources an adopter renames into place.
  // Both carry package: imports that used to be left pointing at the template.
  for (final dirName in [
    'lib',
    'test',
    'integration_test',
    'tool',
    'examples',
  ]) {
    final dir = Directory('$rootPath/$dirName');
    if (!dir.existsSync()) continue;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.dart.template')) {
        continue;
      }
      var text = await entity.readAsString();
      if (text.contains(oldImport)) {
        text = text.replaceAll(oldImport, newImport);
        await entity.writeAsString(text);
      }
    }
  }

  final pubspec = File('$rootPath/pubspec.yaml');
  var yaml = await pubspec.readAsString();
  yaml = yaml.replaceFirstMapped(
    RegExp(r'^name:\s*flutter_starter\s*$', multiLine: true),
    (_) => 'name: $packageName',
  );
  await pubspec.writeAsString(yaml);
  logger.info('Renamed Dart package to $packageName');
}

Future<void> _patchAndroidGradle(String rootPath, String applicationId) async {
  final file = File('$rootPath/android/app/build.gradle.kts');
  if (!file.existsSync()) return;
  var s = await file.readAsString();
  s = s.replaceFirst(
    RegExp('namespace = "[^"]+"'),
    'namespace = "$applicationId"',
  );
  s = s.replaceFirst(
    RegExp('applicationId = "[^"]+"'),
    'applicationId = "$applicationId"',
  );
  await file.writeAsString(s);
}

Future<void> _patchAndroidManifest(String rootPath, String displayName) async {
  final file = File('$rootPath/android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) return;
  var s = await file.readAsString();
  final safeName = displayName.replaceAll('"', "'");
  s = s.replaceFirst(
    RegExp('android:label="[^"]*"'),
    'android:label="$safeName"',
  );
  await file.writeAsString(s);
}

Future<void> _relocateMainActivity(
  String rootPath,
  String applicationId,
  Logger logger,
) async {
  final oldPath =
      '$rootPath/android/app/src/main/kotlin/com/example/flutter_starter/MainActivity.kt';
  final oldFile = File(oldPath);
  if (!oldFile.existsSync()) {
    logger.warn('MainActivity.kt not at default path; skip relocate.');
    return;
  }
  var content = await oldFile.readAsString();
  content = content.replaceFirst(
    RegExp(r'^package .+$', multiLine: true),
    'package $applicationId',
  );
  final segments = applicationId.split('.');
  final newDirPath = '${segments.join('/')}/MainActivity.kt';
  final newFile = File('$rootPath/android/app/src/main/kotlin/$newDirPath');
  await newFile.parent.create(recursive: true);
  await newFile.writeAsString(content);
  await oldFile.delete();
  await _pruneEmptyExamplePackage(
    '$rootPath/android/app/src/main/kotlin',
    'com/example/flutter_starter',
  );
  logger.info('Moved MainActivity to match $applicationId');
}

/// Moves the Patrol native entry point alongside [_relocateMainActivity].
///
/// `MainActivityTest` references `MainActivity.class` without an import, so the
/// two classes must share a package. Leaving this file behind makes the
/// androidTest variant fail to compile with "cannot find symbol class
/// MainActivity", and patching only the package while leaving the directory
/// behind makes javac reject the file for the same reason in reverse.
Future<void> _relocateMainActivityTest(
  String rootPath,
  String applicationId,
  Logger logger,
) async {
  const testRoot = 'android/app/src/androidTest/java';
  final oldFile = File(
    '$rootPath/$testRoot/com/example/flutter_starter/MainActivityTest.java',
  );
  if (!oldFile.existsSync()) {
    logger.warn('MainActivityTest.java not at default path; skip relocate.');
    return;
  }
  var content = await oldFile.readAsString();
  content = content.replaceFirst(
    RegExp(r'^package .+;$', multiLine: true),
    'package $applicationId;',
  );
  final segments = applicationId.split('.');
  final newFile = File(
    '$rootPath/$testRoot/${segments.join('/')}/MainActivityTest.java',
  );
  await newFile.parent.create(recursive: true);
  await newFile.writeAsString(content);
  await oldFile.delete();
  await _pruneEmptyExamplePackage(
    '$rootPath/$testRoot',
    'com/example/flutter_starter',
  );
  logger.info('Moved MainActivityTest to match $applicationId');
}

/// Deletes [relativePackage] under [sourceRoot] and any ancestor left empty.
Future<void> _pruneEmptyExamplePackage(
  String sourceRoot,
  String relativePackage,
) async {
  final leaf = Directory('$sourceRoot/$relativePackage');
  if (leaf.existsSync()) {
    await leaf.delete(recursive: true);
  }
  final segments = relativePackage.split('/');
  for (var i = segments.length - 1; i > 0; i--) {
    final dir = Directory('$sourceRoot/${segments.take(i).join('/')}');
    if (dir.existsSync() && dir.listSync().isEmpty) {
      await dir.delete();
    }
  }
}

Future<void> _patchIosBundleIds(
  String rootPath,
  String iosBundleId,
  Logger logger,
) async {
  final file = File('$rootPath/ios/Runner.xcodeproj/project.pbxproj');
  if (!file.existsSync()) {
    logger.warn('iOS project.pbxproj not found; skip bundle id patch.');
    return;
  }
  var s = await file.readAsString();
  s = s.replaceAll(
    'com.example.flutterStarter.RunnerTests',
    '$iosBundleId.RunnerTests',
  );
  s = s.replaceAll('com.example.flutterStarter', iosBundleId);
  await file.writeAsString(s);
  logger.info('Updated iOS PRODUCT_BUNDLE_IDENTIFIER to $iosBundleId');
}

/// Rewrites the `patrol:` block in pubspec.yaml.
///
/// `patrol test` installs and instruments `android.package_name`. Left at the
/// template value it instruments a package that is no longer installed, which
/// surfaces as a test run against nothing rather than as an error.
Future<void> _patchPatrolConfig(
  String rootPath,
  String applicationId,
  String appDisplayName,
  Logger logger,
) async {
  final pubspec = File('$rootPath/pubspec.yaml');
  if (!pubspec.existsSync()) return;
  var s = await pubspec.readAsString();
  final before = s;
  s = s.replaceFirst(
    RegExp(r'^(\s*)app_name:\s*flutter_starter\s*$', multiLine: true),
    '  app_name: $appDisplayName',
  );
  s = s.replaceFirst(
    RegExp(
      r'^(\s*)package_name:\s*com\.example\.flutter_starter\s*$',
      multiLine: true,
    ),
    '    package_name: $applicationId',
  );
  if (s == before) return;
  await pubspec.writeAsString(s);
  logger.info('Updated patrol config to $applicationId');
}

/// Replaces the template identifiers left in the desktop, web, Apple and
/// fastlane configuration files.
///
/// Every entry is a plain literal substitution, applied longest-first so that
/// `com.example.flutter_starter` is consumed before the bare `flutter_starter`
/// inside it.
Future<void> _patchPlatformIdentifiers({
  required String rootPath,
  required String packageName,
  required String applicationId,
  required String iosBundleId,
  required String appDisplayName,
  required Logger logger,
}) async {
  final segments = applicationId.split('.');
  final organization = segments.length > 1
      ? segments.sublist(0, segments.length - 1).join('.')
      : applicationId;

  // Order is significant: the longer keys must run first.
  final replacements = <String, String>{
    'com.example.flutterStarter': iosBundleId,
    'com.example.flutter_starter': applicationId,
    'Flutter Starter': appDisplayName,
    'flutter_starter': packageName,
    'com.example': organization,
  };

  const files = <String>[
    'macos/Runner/Configs/AppInfo.xcconfig',
    'macos/Runner.xcodeproj/project.pbxproj',
    'macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
    'ios/ExportOptions.plist',
    'ios/Runner/Info.plist',
    'linux/CMakeLists.txt',
    'linux/runner/my_application.cc',
    'windows/CMakeLists.txt',
    'windows/runner/Runner.rc',
    'windows/runner/main.cpp',
    'web/index.html',
    'web/manifest.json',
    'fastlane/Appfile',
    'fastlane/Fastfile',
    'fastlane/README.md',
    'ios/fastlane/Appfile',
    'ios/fastlane/Fastfile',
    '.github/workflows/deploy-android.yml',
    // The scaffolders emit `package:flutter_starter/` imports, and
    // scripts-smoke.yml diffs the two against each other - so they must be
    // rewritten together or not at all.
    'scripts/dev/create_feature.sh',
    'scripts/dev/create_feature.ps1',
    // FreeRASP compares the *running* app's identity against these literals.
    // Left at the template values it flags the renamed app as repackaged, or -
    // worse, the check being a no-op by default - validates nothing at all.
    'lib/core/security/infrastructure/freerasp_service_impl.dart',
  ];

  final patched = <String>[];
  for (final relative in files) {
    final file = File('$rootPath/$relative');
    if (!file.existsSync()) continue;
    var s = await file.readAsString();
    final before = s;
    for (final entry in replacements.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    if (s != before) {
      await file.writeAsString(s);
      patched.add(relative);
    }
  }
  logger.info('Rewrote identifiers in ${patched.length} platform file(s)');
}
