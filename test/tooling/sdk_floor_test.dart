// A pubspec's `environment:` must state at least the SDK floor its committed
// lock resolves against. When it declares less, someone on an SDK between the
// two reads the constraint, believes their SDK is supported, and gets a
// version-solving error from `flutter pub get` that names a transitive package
// instead of the SDK. A declared floor that covers the lock's makes pub say
// "requires SDK version ..." instead.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Every committed pubspec that has a lock beside it.
const _packages = [
  '.',
  'bricks/feature_clean/hooks',
  'bricks/flutter_starter_setup/hooks',
];

/// The lower bound of a constraint such as `^3.13.0`, `>=3.47.0` or
/// `">=3.13.0 <4.0.0"`; null when there is none.
String? lowerBound(Object? constraint) {
  if (constraint == null) return null;
  return RegExp(
    r'(?:\^|>=)\s*(\d+\.\d+\.\d+)',
  ).firstMatch('$constraint')?.group(1);
}

/// Compares dotted numeric versions.
int compareVersions(String a, String b) {
  final x = a.split('.').map(int.parse).toList();
  final y = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// `<sdk>: declared <x>, lock needs <y>` for each SDK [pubspec] declares
/// below what [lock]'s `sdks:` requires.
List<String> floorMismatches(String pubspec, String lock) {
  final environment =
      (loadYaml(pubspec) as YamlMap)['environment'] as YamlMap? ?? YamlMap();
  final sdks = (loadYaml(lock) as YamlMap)['sdks'] as YamlMap? ?? YamlMap();
  return [
    for (final (name, key) in [('dart', 'sdk'), ('flutter', 'flutter')])
      if (lowerBound(sdks[name]) case final needed?)
        if (lowerBound(environment[key]) case final declared
            when declared == null || compareVersions(declared, needed) < 0)
          '$name: declared ${declared ?? 'nothing'}, lock needs $needed',
  ];
}

void main() {
  for (final dir in _packages) {
    test('$dir/pubspec.yaml declares the SDK floor its lock needs', () {
      final mismatches = floorMismatches(
        File('$dir/pubspec.yaml').readAsStringSync(),
        File('$dir/pubspec.lock').readAsStringSync(),
      );
      expect(
        mismatches,
        isEmpty,
        reason:
            'Raise environment: in $dir/pubspec.yaml to what pubspec.lock '
            "'s sdks: block says",
      );
    });
  }

  group('the floor check itself', () {
    const lock = 'sdks:\n  dart: ">=3.13.0 <4.0.0"\n  flutter: ">=3.47.0"\n';

    test('accepts a declared floor equal to or above the lock', () {
      expect(
        floorMismatches(
          "environment:\n  sdk: ^3.13.0\n  flutter: '>=3.48.1'\n",
          lock,
        ),
        isEmpty,
      );
    });

    test('names both values when a declared floor is lower', () {
      expect(
        floorMismatches("environment:\n  sdk: '^3.8.0'\n", lock),
        [
          'dart: declared 3.8.0, lock needs 3.13.0',
          'flutter: declared nothing, lock needs 3.47.0',
        ],
      );
    });

    test('ignores an SDK the lock does not constrain', () {
      expect(
        floorMismatches(
          'environment:\n  sdk: ^3.9.0\n',
          'sdks:\n  dart: ">=3.9.0 <4.0.0"\n',
        ),
        isEmpty,
      );
    });
  });
}
