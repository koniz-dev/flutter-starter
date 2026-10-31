/// What makes each `flutter_starter_setup` variable valid.
///
/// Checked by `pre_gen.dart` before anything is written: `post_gen.dart`
/// strips and renames in place, and an invalid name (a hyphenated
/// `my-app`) failed only at `flutter pub get`, after rewriting hundreds of
/// files into a tree a second run could not repair.
library;

import 'dart:convert';

/// Words a Dart package name cannot be, because the name becomes an
/// identifier (`package:<name>/...` and the generated localizations).
const _reservedWords = <String>{
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
};

/// Why [name] is not a valid pub package name, or `null` if it is.
String? packageNameProblem(String name) {
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    return 'package_name "$name" must be lowercase letters, digits and '
        'underscores, starting with a letter (for example my_app)';
  }
  if (_reservedWords.contains(name)) {
    return 'package_name "$name" is a Dart reserved word';
  }
  return null;
}

/// Why [id] is not a valid Android applicationId, or `null` if it is: at
/// least two dot-separated segments, each starting with a letter and holding
/// only letters, digits and underscores.
String? applicationIdProblem(String id) {
  const segment = '[A-Za-z][A-Za-z0-9_]*';
  if (!RegExp('^$segment(\\.$segment)+\$').hasMatch(id)) {
    return 'application_id "$id" must be at least two dot-separated '
        'segments of letters, digits and underscores, each starting with a '
        'letter (for example com.example.my_app)';
  }
  return null;
}

/// Why [id] is not a valid iOS bundle identifier, or `null` if it is:
/// letters, digits, hyphens and periods only, with no empty segment.
String? iosBundleIdProblem(String id) {
  if (!RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$').hasMatch(id)) {
    return 'ios_bundle_id "$id" must be dot-separated segments of letters, '
        'digits and hyphens (for example com.example.myApp); underscores are '
        'not allowed';
  }
  return null;
}

/// Why [name] cannot be the app's display name, or `null` if it can: it must
/// not be blank, and must not hold a control character, which XML 1.0 (the
/// Android manifest, Info.plist) cannot carry even escaped.
String? displayNameProblem(String name) {
  if (name.trim().isEmpty) return 'app_display_name must not be blank';
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
    return 'app_display_name must not contain a line break, tab or other '
        'control character';
  }
  return null;
}

/// [text] escaped for an XML attribute value or element content.
String xmlEscaped(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// [text] as a double-quoted YAML scalar, quotes included. JSON's string
/// syntax is a subset of YAML's double-quoted style.
String yamlQuoted(String text) => jsonEncode(text);

/// [text] escaped for the inside of a Ruby double-quoted string: `"`, `\`
/// and the `#` that would start an interpolation.
String rubyDoubleQuotedEscaped(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('#', r'\#');
