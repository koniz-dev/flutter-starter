import 'package:mason/mason.dart';

import 'input_rules.dart';

/// Rejects an invalid feature or class name before any file is generated.
void run(HookContext context) {
  final problems = [
    featureNameProblem(context.vars['feature_name'] as String),
    classNameProblem(context.vars['class_name'] as String),
  ].nonNulls.toList();
  if (problems.isEmpty) return;
  problems.forEach(context.logger.err);
  throw ArgumentError('feature_clean: invalid input, nothing was generated.');
}
