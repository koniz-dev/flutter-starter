/// What makes a `feature_clean` feature name valid: the rule
/// `scripts/dev/create_feature.sh` applies, so the brick and the script
/// accept the same names. A hyphenated `user-profile` generated files the
/// analyzer then rejected (`file_names`).
library;

import 'dart:io';

/// Why [name] is not a snake_case feature name, or `null` if it is.
String? featureNameProblem(String name) {
  if (!RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$').hasMatch(name)) {
    return 'feature_name "$name" must be snake_case (for example '
        'user_profile)';
  }
  return null;
}

/// Why [name] is not an UpperCamelCase class name, or `null` if it is.
///
/// Every generated type is named from it (`Get{{class_name}}ByIdUseCase`), so
/// `user_profile` generated code that failed `camel_case_types`, and
/// `Order Item` generated code that did not parse.
String? classNameProblem(String name) {
  if (!RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(name)) {
    return 'class_name "$name" must be UpperCamelCase (for example '
        'UserProfile)';
  }
  return null;
}

/// Why a feature named [featureName] cannot be generated under [root], or
/// `null` if nothing is in the way.
///
/// The brick writes into `lib/features/<name>` and `test/features/<name>`.
/// Run for a feature that already exists (`auth`), Mason prompted to
/// overwrite its files one by one - or, with no terminal, failed part-way
/// and left the files it had already written. `create_feature.sh` refuses
/// in that case; this is the same rule and the same message.
String? existingFeatureProblem(String featureName, {required String root}) {
  final lib = 'lib/features/$featureName';
  final test = 'test/features/$featureName';
  final exists = [lib, test].any(
    // Links are not followed: a dangling link is in the way too.
    (path) =>
        FileSystemEntity.typeSync('$root/$path', followLinks: false) !=
        FileSystemEntityType.notFound,
  );
  if (!exists) return null;
  return '$lib or $test already exists; refusing to overwrite';
}
