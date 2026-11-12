import 'dart:io';

import 'package:mason/mason.dart';

import 'input_rules.dart';

/// Rejects an invalid feature or class name, or a feature that already
/// exists, before any file is generated.
void run(HookContext context) {
  final featureName = context.vars['feature_name'] as String;
  final problems = [
    featureNameProblem(featureName),
    classNameProblem(context.vars['class_name'] as String),
  ].nonNulls.toList();
  if (problems.isEmpty) {
    // Mason runs hooks with the generation output folder as the working
    // directory. Checked only for a valid name: an invalid one is not a path.
    final existing = existingFeatureProblem(
      featureName,
      root: Directory.current.path,
    );
    if (existing != null) problems.add(existing);
  }
  if (problems.isEmpty) return;
  problems.forEach(context.logger.err);
  throw ArgumentError('feature_clean: invalid input, nothing was generated.');
}
