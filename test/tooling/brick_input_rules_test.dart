// The bricks validate their input in pre_gen, before anything is written.
// flutter_starter_setup used to accept `my-app`, rewrite hundreds of files
// and only then fail at `flutter pub get`, leaving a tree a second run could
// not repair; feature_clean accepted `user-profile` and generated files the
// analyzer rejected.

import 'package:flutter_test/flutter_test.dart';

import '../../bricks/feature_clean/hooks/input_rules.dart' as feature;
import '../../bricks/flutter_starter_setup/hooks/input_rules.dart' as setup;

void main() {
  group('flutter_starter_setup package_name', () {
    for (final name in ['my_app', 'acme', 'shop2', 'a_b_c']) {
      test('accepts $name', () {
        expect(setup.packageNameProblem(name), isNull);
      });
    }
    for (final name in [
      'my-app',
      'MyApp',
      '1app',
      '_app',
      'my app',
      '',
      'class',
      'void',
    ]) {
      test('rejects "$name"', () {
        expect(setup.packageNameProblem(name), isNotNull);
      });
    }
  });

  group('flutter_starter_setup application_id', () {
    for (final id in ['com.example.my_app', 'io.acme.Shop2']) {
      test('accepts $id', () {
        expect(setup.applicationIdProblem(id), isNull);
      });
    }
    for (final id in [
      'myapp',
      'com.example.my-app',
      'com..app',
      'com.1app',
      '.com.app',
      'com.app.',
    ]) {
      test('rejects "$id"', () {
        expect(setup.applicationIdProblem(id), isNotNull);
      });
    }
  });

  group('flutter_starter_setup ios_bundle_id', () {
    for (final id in [
      'com.example.myApp',
      'com.example.my-app',
      'io.acme.Shop2',
    ]) {
      test('accepts $id', () {
        expect(setup.iosBundleIdProblem(id), isNull);
      });
    }
    for (final id in [
      'myApp',
      'com.example.my_app',
      'com..app',
      'com.app.',
      'com.my app',
    ]) {
      test('rejects "$id"', () {
        expect(setup.iosBundleIdProblem(id), isNotNull);
      });
    }
  });

  group('feature_clean feature_name', () {
    for (final name in ['profile', 'user_profile', 'settings_v2', 'x1']) {
      test('accepts $name', () {
        expect(feature.featureNameProblem(name), isNull);
      });
    }
    for (final name in [
      'user-profile',
      'UserProfile',
      '1abc',
      'user__profile',
      '_x',
      'a b',
      '',
    ]) {
      test('rejects "$name"', () {
        expect(feature.featureNameProblem(name), isNotNull);
      });
    }
  });
}
