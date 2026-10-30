import 'package:mason/mason.dart';

import 'input_rules.dart';

/// Rejects invalid input before anything is generated, stripped or renamed.
void run(HookContext context) {
  final problems = [
    packageNameProblem(context.vars['package_name'] as String),
    applicationIdProblem(context.vars['application_id'] as String),
    iosBundleIdProblem(context.vars['ios_bundle_id'] as String),
  ].whereType<String>().toList();
  if (problems.isEmpty) return;
  problems.forEach(context.logger.err);
  throw ArgumentError(
    'flutter_starter_setup: invalid input, nothing was changed.',
  );
}
