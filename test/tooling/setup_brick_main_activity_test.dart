// The setup brick moves MainActivity.kt and the Patrol MainActivityTest.java
// into the package directory of the chosen application_id, then removes the
// template's com/example/flutter_starter directory. An id equal to the
// template's, nested under it, or (on a case-insensitive filesystem) a case
// variant of it puts the new file inside that directory, so neither the move
// nor the cleanup may delete it.
//
// As in setup_brick_log_test.dart, the hook source is compiled into a probe
// so its private relocation helpers run unchanged, on copies of the two files.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _hookPath = 'bricks/flutter_starter_setup/hooks/post_gen.dart';
const _kotlinRoot = 'android/app/src/main/kotlin';
const _javaRoot = 'android/app/src/androidTest/java';
const _templatePackage = 'com/example/flutter_starter';
const _activity = '$_kotlinRoot/$_templatePackage/MainActivity.kt';
const _activityTest = '$_javaRoot/$_templatePackage/MainActivityTest.java';

String? _skipReason() {
  if (!File(_hookPath).existsSync()) return 'the setup brick has been removed';
  if (!File(_activity).existsSync() || !File(_activityTest).existsSync()) {
    return 'MainActivity has already been moved out of the template package';
  }
  return null;
}

/// One application id, run on its own copy of the two files.
class _Case {
  const _Case(this.id, {this.finderMetadata = false});

  final String id;

  /// Whether the template package also holds a `.DS_Store`, as it does once
  /// Finder has opened it.
  final bool finderMetadata;

  String get label =>
      finderMetadata ? '$id with a .DS_Store in the template package' : id;
}

const _cases = [
  _Case('com.example.flutter_starter'),
  _Case('com.example.flutter_starter.dev'),
  _Case('com.Example.flutter_starter'),
  _Case('com.example.other'),
  _Case('com.acme.shop'),
  _Case('com.acme.shop', finderMetadata: true),
];

void main() {
  final skip = _skipReason();
  late Directory base;

  setUpAll(() async {
    if (skip != null) return;
    base = Directory.systemTemp.createTempSync('setup_main_activity_');
    for (var i = 0; i < _cases.length; i++) {
      for (final relative in [_activity, _activityTest]) {
        File('${base.path}/$i/$relative')
          ..createSync(recursive: true)
          ..writeAsStringSync(File(relative).readAsStringSync());
        if (_cases[i].finderMetadata) {
          File(
            '${base.path}/$i/${File(relative).parent.path}/.DS_Store',
          ).writeAsStringSync('finder');
        }
      }
    }
    File(
      'bricks/flutter_starter_setup/hooks/input_rules.dart',
    ).copySync('${base.path}/input_rules.dart');
    final probe = File('${base.path}/post_gen_probe.dart')
      ..writeAsStringSync('''
${File(_hookPath).readAsStringSync()}
Future<void> main(List<String> args) async {
  final logger = Logger();
  for (var i = 1; i < args.length; i++) {
    final root = '\${args[0]}/\${i - 1}';
    await _relocateMainActivity(root, args[i], logger);
    await _relocateMainActivityTest(root, args[i], logger);
  }
}
''');
    final result = await Process.run('dart', [
      '--packages=${File('.dart_tool/package_config.json').absolute.path}',
      probe.path,
      base.path,
      for (final c in _cases) c.id,
    ]);
    if (result.exitCode != 0) {
      fail('hook failed: ${result.stdout}\n${result.stderr}');
    }
  });

  tearDownAll(() {
    if (skip == null && base.existsSync()) base.deleteSync(recursive: true);
  });

  for (var i = 0; i < _cases.length; i++) {
    final id = _cases[i].id;
    test('application_id ${_cases[i].label} keeps both entry points', () {
      final root = '${base.path}/$i';
      final dir = id.replaceAll('.', '/');

      final activity = File('$root/$_kotlinRoot/$dir/MainActivity.kt');
      expect(activity.existsSync(), isTrue, reason: activity.path);
      expect(
        activity.readAsStringSync(),
        matches(RegExp('^package ${RegExp.escape(id)}\$', multiLine: true)),
      );

      final activityTest = File('$root/$_javaRoot/$dir/MainActivityTest.java');
      expect(activityTest.existsSync(), isTrue, reason: activityTest.path);
      expect(
        activityTest.readAsStringSync(),
        matches(RegExp('^package ${RegExp.escape(id)};\$', multiLine: true)),
      );

      // Exactly one copy of each, so nothing is left behind at the old path.
      for (final name in ['MainActivity.kt', 'MainActivityTest.java']) {
        final copies = Directory('$root/android')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last == name);
        expect(copies, hasLength(1), reason: name);
      }
    }, skip: skip);
  }

  test('a sibling id removes the template package but keeps its parent', () {
    final i = _cases.indexWhere((c) => c.id == 'com.example.other');
    final root = '${base.path}/$i';
    for (final sourceRoot in [_kotlinRoot, _javaRoot]) {
      expect(
        Directory('$root/$sourceRoot/$_templatePackage').existsSync(),
        isFalse,
        reason: sourceRoot,
      );
      expect(
        Directory('$root/$sourceRoot/com/example/other').existsSync(),
        isTrue,
        reason: sourceRoot,
      );
    }
  }, skip: skip);

  for (final finderMetadata in [false, true]) {
    final i = _cases.indexWhere(
      (c) => c.id == 'com.acme.shop' && c.finderMetadata == finderMetadata,
    );
    test('${_cases[i].label} removes the emptied com/example tree', () {
      final root = '${base.path}/$i';
      for (final sourceRoot in [_kotlinRoot, _javaRoot]) {
        expect(
          Directory('$root/$sourceRoot/com/example').existsSync(),
          isFalse,
          reason: sourceRoot,
        );
      }
    }, skip: skip);
  }
}
