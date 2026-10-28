import 'dart:convert';
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
  await _applyDisplayNameToDart(rootPath, appDisplayName, logger);
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

  // Last, because it needs the renamed package resolved and the regenerated
  // localizations in place. Without it the tree analyzed clean before the
  // rename and red after it.
  await _repairRenamedSources(rootPath, logger);

  logger.alert('Setup complete. Next: flutter analyze && flutter test');
}

/// Every directory whose `.dart` sources [_renameDartPackage] rewrites.
///
/// `docs/` is here because `analysis_options.yaml` does not exclude it (see
/// CLAUDE.md), so a committed probe such as
/// a `.dart` file under `docs/` would be analyzed like any
/// other source; left importing `package:flutter_starter/` it fails analysis
/// with `uri_does_not_exist` once the package is renamed.
/// Root markdown whose code samples import the package.
const _renamedRootMarkdown = <String>['README.md', 'CONTRIBUTING.md'];

const _renamedDirectories = <String>[
  'lib',
  'test',
  'integration_test',
  'tool',
  'examples',
  'docs',
];

/// Re-resolves the renamed package, regenerates localizations, and repairs
/// the import order the rename broke.
///
/// `package:flutter_starter/` happened to sort between `flutter_riverpod` and
/// `flutter_test`. Almost any other name does not, so a string replace leaves
/// nearly every multi-import file violating `directives_ordering` - 175 of
/// them for `acme_shop`, and as many for the default `my_app`.
/// `dart fix --code=directives_ordering`, run over the repository root,
/// reorders exactly those blocks, and `dart format` then normalises the
/// directories the rename touched so the format gate stays green.
Future<void> _repairRenamedSources(String rootPath, Logger logger) async {
  final dirs = _renamedDirectories
      .where((d) => Directory('$rootPath/$d').existsSync())
      .toList();

  await _run('flutter', ['pub', 'get'], rootPath, logger);
  await _run('flutter', ['gen-l10n'], rootPath, logger);
  // `dart fix` takes a single path. The root covers every analyzed file -
  // the directories above, and nothing `analysis_options.yaml` excludes.
  await _run(
    'dart',
    ['fix', '--apply', '--code=directives_ordering', '.'],
    rootPath,
    logger,
  );
  await _run('dart', ['format', ...dirs], rootPath, logger);
  logger.info('Re-sorted imports and reformatted ${dirs.join(', ')}');
}

Future<void> _run(
  String executable,
  List<String> args,
  String workingDirectory,
  Logger logger,
) async {
  final result = await Process.run(
    executable,
    args,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    logger
      ..err(result.stdout.toString())
      ..err(result.stderr.toString());
    throw Exception(
      '`$executable ${args.join(' ')}` failed with exit ${result.exitCode}',
    );
  }
}

/// Puts [displayName] where the Dart side shows the app's name.
///
/// Only the exact template name is replaced: the whole-string `'Flutter
/// Starter'` literal (in `MaterialApp.title`, `StartupFailureApp`,
/// `AppConstants.appName`, and the tests that assert them) and the `appTitle`
/// entry of every ARB file. Sentences that merely mention the template, such
/// as `welcome`, are left alone. The generated `app_localizations*.dart` are
/// rebuilt from the ARB files by `flutter gen-l10n` in
/// [_repairRenamedSources].
Future<void> _applyDisplayNameToDart(
  String rootPath,
  String displayName,
  Logger logger,
) async {
  const templateName = 'Flutter Starter';
  final dartLiteral = _dartSingleQuoted(displayName);
  final arbEntry = RegExp(r'"appTitle"\s*:\s*"Flutter Starter"');
  final arbValue = '"appTitle": ${jsonEncode(displayName)}';

  var changed = 0;
  // tool/golden holds the copies tool/strip_sample_features.dart writes over
  // lib/; left on the template name, a strip after the rename put it back.
  for (final dirName in ['lib', 'test', 'integration_test', 'tool/golden']) {
    final dir = Directory('$rootPath/$dirName');
    if (!dir.existsSync()) continue;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      final isDart = path.endsWith('.dart');
      final isArb = path.endsWith('.arb');
      if (!isDart && !isArb) continue;
      final text = await entity.readAsString();
      final updated = isDart
          ? text.replaceAll("'$templateName'", dartLiteral)
          : text.replaceAll(arbEntry, arbValue);
      if (updated != text) {
        await entity.writeAsString(updated);
        changed++;
      }
    }
  }
  logger.info('Applied "$displayName" to $changed Dart/ARB file(s)');
}

/// [value] as a single-quoted Dart string literal.
String _dartSingleQuoted(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
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
  // `docs/` is in the list for the reason given on [_renamedDirectories].
  for (final dirName in _renamedDirectories) {
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

  // The root guides show code an adopter's team copies; CONTRIBUTING's
  // example test imports the package.
  for (final name in _renamedRootMarkdown) {
    final file = File('$rootPath/$name');
    if (!file.existsSync()) continue;
    final text = await file.readAsString();
    if (text.contains(oldImport)) {
      await file.writeAsString(text.replaceAll(oldImport, newImport));
    }
  }

  final brickFiles = await rewriteFeatureBrickImports(rootPath, packageName);
  logger.info('Rewrote $brickFiles feature_clean brick template(s)');

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
/// Rewrites `package:flutter_starter/` in the `feature_clean` brick's
/// templates to `package:<packageName>/`, returning how many files changed.
///
/// README and `mason-demo-script.md` document `mason make feature_clean` after
/// setup. Left alone, every feature the brick generates imports the template
/// package and does not resolve. The templates
/// are deliberately not in [_renamedDirectories]: that list is also handed to
/// `dart fix` and `dart format`, which cannot parse mustache. Only the import
/// prefix is replaced, so mustache tags and templated filenames are untouched.
Future<int> rewriteFeatureBrickImports(
  String rootPath,
  String packageName,
) async {
  const oldImport = 'package:flutter_starter/';
  final dir = Directory('$rootPath/bricks/feature_clean/__brick__');
  if (!dir.existsSync()) return 0;
  var rewritten = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final text = await entity.readAsString();
    if (!text.contains(oldImport)) continue;
    await entity.writeAsString(
      text.replaceAll(oldImport, 'package:$packageName/'),
    );
    rewritten++;
  }
  return rewritten;
}

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
