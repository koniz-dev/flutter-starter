// The bricks validate their input in pre_gen, before anything is written.
// flutter_starter_setup used to accept `my-app`, rewrite hundreds of files
// and only then fail at `flutter pub get`, leaving a tree a second run could
// not repair; feature_clean accepted `user-profile` and generated files the
// analyzer rejected.

import 'dart:io';

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

  group('displayNameProblem', () {
    test('accepts any printable name', () {
      expect(setup.displayNameProblem('Tom & "Jerry": #1'), isNull);
      expect(setup.displayNameProblem('Café Ünïcode 名前'), isNull);
      expect(setup.displayNameProblem("Tom's App @ home?"), isNull);
    });

    test('rejects what cannot be escaped where the name lands', () {
      for (final bad in [
        '',
        '   ',
        'two\nlines',
        'tab\there',
        'nul\x00',
        'line\u2028separator',
        'ICU {placeholder}',
        'brace }',
        '@string/app_name',
        '?attr/name',
      ]) {
        expect(setup.displayNameProblem(bad), isNotNull, reason: bad);
      }
    });
  });

  group('flutter_starter_setup package_name against the dependencies', () {
    final locked = setup.lockedPackages(
      File('pubspec.lock').readAsStringSync(),
    );

    test("the lock file lists the project's dependencies", () {
      expect(locked, containsAll(<String>['crypto', 'clock', 'dio']));
      expect(locked, isNot(contains('packages')));
    });

    for (final name in ['crypto', 'clock']) {
      test('$name, a dependency, is refused', () {
        expect(
          setup.packageNameProblem(name, dependencies: locked),
          contains('depends on'),
        );
      });
    }

    test('a name no dependency uses is accepted', () {
      expect(
        setup.packageNameProblem('acme_shop', dependencies: locked),
        isNull,
      );
    });
  });

  test('pre_gen refuses a dependency name before anything is written', () {
    // The real hook, in a scratch project holding this project's lock file.
    final dir = Directory.systemTemp.createTempSync('pre_gen_clash_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('pubspec.lock').copySync('${dir.path}/pubspec.lock');
    final hook = File(
      'bricks/flutter_starter_setup/hooks/pre_gen.dart',
    ).absolute.uri;
    final script = File('${dir.path}/run_pre_gen.dart')
      ..writeAsStringSync('''
import 'package:mason/mason.dart';
import '$hook' as hook;

class _Context implements HookContext {
  @override
  Map<String, dynamic> vars = {
    'package_name': 'crypto',
    'application_id': 'com.acme.shop',
    'ios_bundle_id': 'com.acme.shop',
    'app_display_name': 'Shop',
  };

  @override
  final Logger logger = Logger();
}

void main() => hook.run(_Context());
''');
    final before = dir.listSync().map((e) => e.path).toSet();

    final result = Process.runSync('dart', [
      '--packages=${File('.dart_tool/package_config.json').absolute.path}',
      script.path,
    ], workingDirectory: dir.path);

    expect(result.exitCode, isNot(0));
    expect('${result.stdout}${result.stderr}', contains('depends on'));
    expect(dir.listSync().map((e) => e.path).toSet(), before);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
