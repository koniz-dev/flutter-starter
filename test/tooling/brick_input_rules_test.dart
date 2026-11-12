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

  group('feature_clean class_name', () {
    for (final name in ['Profile', 'UserProfile', 'SettingsV2', 'X1']) {
      test('accepts $name', () {
        expect(feature.classNameProblem(name), isNull);
      });
    }
    for (final name in [
      'user_profile',
      'Order Item',
      'profile',
      'User-Profile',
      'User_Profile',
      '1Profile',
      '',
    ]) {
      test('rejects "$name"', () {
        expect(feature.classNameProblem(name), isNotNull);
      });
    }
  });

  test('feature_clean pre_gen refuses a bad class_name', () {
    final dir = Directory.systemTemp.createTempSync('feature_pre_gen_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final hook = File('bricks/feature_clean/hooks/pre_gen.dart').absolute.uri;
    final script = File('${dir.path}/run_pre_gen.dart')
      ..writeAsStringSync('''
import 'package:mason/mason.dart';
import '$hook' as hook;

class _Context implements HookContext {
  @override
  Map<String, dynamic> vars = {
    'feature_name': 'user_profile',
    'class_name': 'user_profile',
    'include_tests': true,
  };

  @override
  final Logger logger = Logger();
}

void main() => hook.run(_Context());
''');

    final result = Process.runSync('dart', [
      '--packages=${File('.dart_tool/package_config.json').absolute.path}',
      script.path,
    ], workingDirectory: dir.path);

    expect(result.exitCode, isNot(0));
    expect('${result.stdout}${result.stderr}', contains('UpperCamelCase'));
  }, timeout: const Timeout(Duration(minutes: 2)));

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

  // The brick used to write into a feature that already existed - prompting
  // to overwrite its files, or failing part-way with no terminal attached.
  group('feature_clean existing feature', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('feature_clean_existing_');
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('nothing in the way is accepted', () {
      Directory('${root.path}/lib/features/auth').createSync(recursive: true);

      expect(feature.existingFeatureProblem('notes', root: root.path), isNull);
    });

    test('an existing lib/features/<name> is refused', () {
      Directory('${root.path}/lib/features/auth').createSync(recursive: true);

      expect(
        feature.existingFeatureProblem('auth', root: root.path),
        'lib/features/auth or test/features/auth already exists; '
        'refusing to overwrite',
      );
    });

    test('an existing test/features/<name> alone is refused', () {
      Directory('${root.path}/test/features/auth').createSync(recursive: true);

      expect(
        feature.existingFeatureProblem('auth', root: root.path),
        contains('refusing to overwrite'),
      );
    });

    test('a file of that name is in the way too', () {
      File('${root.path}/lib/features/auth').createSync(recursive: true);

      expect(
        feature.existingFeatureProblem('auth', root: root.path),
        contains('refusing to overwrite'),
      );
    });

    test('a dangling link of that name is in the way too', () {
      Directory('${root.path}/lib/features').createSync(recursive: true);
      Link('${root.path}/lib/features/auth').createSync('${root.path}/gone');

      expect(
        feature.existingFeatureProblem('auth', root: root.path),
        contains('refusing to overwrite'),
      );
    }, testOn: '!windows');

    test('the message is the one both create_feature scripts print', () {
      Directory('${root.path}/lib/features/auth').createSync(recursive: true);
      final message = feature.existingFeatureProblem('auth', root: root.path)!;
      final sh = File('scripts/dev/create_feature.sh').readAsStringSync();
      final ps1 = File('scripts/dev/create_feature.ps1').readAsStringSync();

      // Each script's own line, with its variables filled in for `auth`.
      final fromSh = RegExp(
        r'echo "Error: (\$BASE_DIR or \$TEST_DIR [^"]+)"',
      ).firstMatch(sh)!.group(1)!;
      final fromPs1 = RegExp(
        r'Write-Error "(\$BaseDir or \$TestDir [^"]+)"',
      ).firstMatch(ps1)!.group(1)!;
      String filled(String line) => line
          .replaceFirst(RegExp(r'\$(BASE_DIR|BaseDir)'), 'lib/features/auth')
          .replaceFirst(RegExp(r'\$(TEST_DIR|TestDir)'), 'test/features/auth');

      expect(filled(fromSh), message);
      expect(filled(fromPs1), message);
    });

    test('pre_gen refuses an existing feature and writes nothing', () {
      Directory(
        '${root.path}/lib/features/user_profile',
      ).createSync(recursive: true);
      final hook = File('bricks/feature_clean/hooks/pre_gen.dart').absolute.uri;
      // Outside the output directory, so the listing below is the hook's.
      final scripts = Directory.systemTemp.createTempSync('feature_pre_gen_');
      addTearDown(() => scripts.deleteSync(recursive: true));
      final script = File('${scripts.path}/run_pre_gen.dart')
        ..writeAsStringSync('''
import 'package:mason/mason.dart';
import '$hook' as hook;

class _Context implements HookContext {
  @override
  Map<String, dynamic> vars = {
    'feature_name': 'user_profile',
    'class_name': 'UserProfile',
    'include_tests': true,
  };

  @override
  final Logger logger = Logger();
}

void main() => hook.run(_Context());
''');
      List<String> listing() => [
        for (final entity in root.listSync(recursive: true)) entity.path,
      ]..sort();
      final before = listing();

      final result = Process.runSync('dart', [
        '--packages=${File('.dart_tool/package_config.json').absolute.path}',
        script.path,
      ], workingDirectory: root.path);

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}${result.stderr}',
        contains(
          'lib/features/user_profile or test/features/user_profile already '
          'exists; refusing to overwrite',
        ),
      );
      expect(listing(), before);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
