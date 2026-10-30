// freerasp used to be a default dependency while RASP was a no-op. Its
// closed-source SDK was linked into every Android release anyway, adding
// READ_GSERVICES, SMS and call-intent package queries and other permissions
// an app that never turned RASP on had to declare. It now ships as an opt-in
// template, like the Firebase adapters; these keep it that way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec.yaml does not depend on freerasp', () {
    final dependency = RegExp(r'^\s+freerasp\s*:', multiLine: true);
    expect(
      dependency.hasMatch(File('pubspec.yaml').readAsStringSync()),
      isFalse,
    );
  });

  test('no lockfile resolves freerasp', () {
    for (final lock in ['pubspec.lock', 'ios/Podfile.lock']) {
      final file = File(lock);
      if (!file.existsSync()) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains('freerasp')),
        reason: lock,
      );
    }
  });

  test('no compiled source imports freerasp', () {
    final importers = [
      for (final dir in ['lib', 'test', 'integration_test'])
        if (Directory(dir).existsSync())
          ...Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .where(
                (f) => RegExp(
                  '''^import ['"]package:freerasp/''',
                  multiLine: true,
                ).hasMatch(f.readAsStringSync()),
              )
              .map((f) => f.path),
    ];
    expect(importers, isEmpty);
  });

  test('the adapter and its tests still ship as templates', () {
    for (final path in [
      'lib/core/security/infrastructure/freerasp_service_impl.dart.template',
      'test/core/security/infrastructure/freerasp_service_impl_test.dart.template',
      'test/core/security/infrastructure/freerasp_start_retry_test.dart.template',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
