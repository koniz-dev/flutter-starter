import 'dart:io';

import 'package:mason/mason.dart';

import 'input_rules.dart';

/// Rejects invalid input before anything is generated, stripped or renamed.
void run(HookContext context) {
  final problems = [
    packageNameProblem(
      context.vars['package_name'] as String,
      dependencies: _lockedPackages(),
    ),
    applicationIdProblem(context.vars['application_id'] as String),
    iosBundleIdProblem(context.vars['ios_bundle_id'] as String),
    displayNameProblem(context.vars['app_display_name'] as String),
  ].whereType<String>().toList();
  if (problems.isNotEmpty) {
    problems.forEach(context.logger.err);
    throw ArgumentError(
      'flutter_starter_setup: invalid input, nothing was changed.',
    );
  }

  final problem = _existingSetupProblem();
  if (problem != null) {
    context.logger.err(problem);
    throw StateError('flutter_starter_setup: nothing was changed.');
  }
}

/// The post-generation substitutions start from template identifiers. Refuse
/// before Mason generates files if a previous setup (or manual edit) changed
/// them; patching only the remaining defaults would produce a partial rename.
String? _existingSetupProblem() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'Run flutter_starter_setup from the starter project root '
        '(pubspec.yaml is missing).';
  }
  final customized = <String>[];
  if (!RegExp(
    r'^name:\s*flutter_starter\s*$',
    multiLine: true,
  ).hasMatch(pubspec.readAsStringSync())) {
    customized.add('pubspec.yaml package name');
  }
  final identifiers = [
    (
      'android/app/build.gradle.kts',
      RegExp(r'\b(?:namespace|applicationId)\s*=\s*"([^"]+)"'),
      {'com.example.flutter_starter'},
    ),
    (
      'ios/Runner.xcodeproj/project.pbxproj',
      RegExp(r'\bPRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\s]+)\s*;'),
      {'com.example.flutterStarter', 'com.example.flutterStarter.RunnerTests'},
    ),
    (
      'macos/Runner/Configs/AppInfo.xcconfig',
      RegExp(r'^PRODUCT_BUNDLE_IDENTIFIER\s*=\s*(\S+)\s*$', multiLine: true),
      {'com.example.flutterStarter'},
    ),
    (
      'linux/CMakeLists.txt',
      RegExp(r'set\(APPLICATION_ID\s+"([^"]+)"\)'),
      {'com.example.flutter_starter'},
    ),
  ];
  for (final (path, pattern, defaults) in identifiers) {
    final file = File(path);
    // Adopters may have removed platforms they do not target.
    if (!file.existsSync()) continue;
    final values = pattern.allMatches(file.readAsStringSync()).toList();
    if (values.isEmpty || values.any((match) => !defaults.contains(match[1]))) {
      customized.add(path);
    }
  }
  if (customized.isEmpty) return null;
  return 'This project is already customized (${customized.join(', ')}). '
      'The setup brick only renames an unrenamed starter. To change an id '
      'again, follow docs/guides/onboarding/fork-and-customize.md, Option B '
      '(Manual), adapting the old identifiers to your current values. '
      'Nothing was changed.';
}

/// The packages the project resolves, from the pubspec.lock in the directory
/// mason generates into (the project root); empty when there is none.
Set<String> _lockedPackages() {
  final lock = File('pubspec.lock');
  return lock.existsSync() ? lockedPackages(lock.readAsStringSync()) : {};
}
