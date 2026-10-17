// docs/api/core/errors.md must document ServerFailure's real constructor
// (koniz-dev/flutter-starter#474).
//
// #309 added `statusCode` to ServerFailure, and the documented signature had
// no way to notice: tool/doc_signatures.dart checks only multi-line
// named-parameter constructors and compares parameter text, so a one-line
// `const ServerFailure(super.message, {super.code, this.statusCode})` can
// never match a documented `String message, {String? code, ...}`. This
// compares parameter *names*, positional and named, which is what a reader
// copies.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Positional and named parameter names in a `ServerFailure(...)` parameter
/// list, with `super.` / `this.` / types stripped.
({List<String> positional, List<String> named}) _parameters(String list) {
  final brace = list.indexOf('{');
  List<String> split(String part) => [
    for (final p in part.split(','))
      if (p.trim().isNotEmpty)
        RegExp(r'(\w+)\s*$').firstMatch(p.trim())!.group(1)!,
  ];
  return (
    positional: split(brace < 0 ? list : list.substring(0, brace)),
    named: brace < 0
        ? const []
        : split(list.substring(brace + 1, list.lastIndexOf('}'))),
  );
}

String _constructorParameters(String source) => RegExp(
  r'const ServerFailure\((.*?)\);',
  dotAll: true,
).firstMatch(source)!.group(1)!;

void main() {
  test(
    'the ServerFailure constructor in errors.md has the real parameters',
    () {
      final doc = File('docs/api/core/errors.md').readAsStringSync();
      final section = doc.substring(doc.indexOf('#### `ServerFailure`'));
      final documented = _parameters(_constructorParameters(section));
      final real = _parameters(
        _constructorParameters(
          File('lib/core/errors/failures.dart').readAsStringSync(),
        ),
      );

      expect(real.positional, ['message']);
      expect(real.named, contains('statusCode'));
      expect(documented.positional, real.positional);
      expect(documented.named, real.named);
    },
  );
}
