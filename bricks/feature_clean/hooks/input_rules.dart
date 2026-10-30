/// What makes a `feature_clean` feature name valid: the rule
/// `scripts/dev/create_feature.sh` applies, so the brick and the script
/// accept the same names. A hyphenated `user-profile` generated files the
/// analyzer then rejected (`file_names`).
library;

/// Why [name] is not a snake_case feature name, or `null` if it is.
String? featureNameProblem(String name) {
  if (!RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$').hasMatch(name)) {
    return 'feature_name "$name" must be snake_case (for example '
        'user_profile)';
  }
  return null;
}
