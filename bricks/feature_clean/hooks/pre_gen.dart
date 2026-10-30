import 'package:mason/mason.dart';

import 'input_rules.dart';

/// Rejects an invalid feature name before any file is generated.
void run(HookContext context) {
  final problem = featureNameProblem(context.vars['feature_name'] as String);
  if (problem == null) return;
  context.logger.err(problem);
  throw ArgumentError('feature_clean: invalid input, nothing was generated.');
}
