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
  if (problems.isEmpty) return;
  problems.forEach(context.logger.err);
  throw ArgumentError(
    'flutter_starter_setup: invalid input, nothing was changed.',
  );
}

/// The packages the project resolves, from the pubspec.lock in the directory
/// mason generates into (the project root); empty when there is none.
Set<String> _lockedPackages() {
  final lock = File('pubspec.lock');
  return lock.existsSync() ? lockedPackages(lock.readAsStringSync()) : {};
}
