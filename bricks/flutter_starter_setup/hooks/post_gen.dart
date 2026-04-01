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
  await _patchIosBundleIds(rootPath, iosBundleId, logger);

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
  for (final dirName in ['lib', 'test', 'integration_test', 'tool']) {
    final dir = Directory('$rootPath/$dirName');
    if (!dir.existsSync()) continue;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
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
  final oldPackageDir = Directory(
    '$rootPath/android/app/src/main/kotlin/com/example/flutter_starter',
  );
  if (oldPackageDir.existsSync()) {
    await oldPackageDir.delete(recursive: true);
  }
  final exampleDir = Directory(
    '$rootPath/android/app/src/main/kotlin/com/example',
  );
  if (exampleDir.existsSync() && exampleDir.listSync().isEmpty) {
    await exampleDir.delete(recursive: true);
  }
  logger.info('Moved MainActivity to match $applicationId');
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
