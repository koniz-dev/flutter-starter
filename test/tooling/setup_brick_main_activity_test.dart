// The setup brick moves MainActivity.kt and the Patrol MainActivityTest.java
// into the package directory of the chosen application_id, then removes the
// template's com/example/flutter_starter directory. An id equal to the
// template's, or nested under it, puts the new file inside that directory, so
// the cleanup must not take the moved file with it.
//
// As in setup_brick_log_test.dart, the hook source is compiled into a probe
// so its private relocation helpers run unchanged, on copies of the two files.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _hookPath = 'bricks/flutter_starter_setup/hooks/post_gen.dart';
const _activity =
    'android/app/src/main/kotlin/com/example/flutter_starter/MainActivity.kt';
const _activityTest =
    'android/app/src/androidTest/java/com/example/flutter_starter/'
    'MainActivityTest.java';

String? _skipReason() {
  if (!File(_hookPath).existsSync()) return 'the setup brick has been removed';
  if (!File(_activity).existsSync() || !File(_activityTest).existsSync()) {
    return 'MainActivity has already been moved out of the template package';
  }
  return null;
}

/// Runs both relocation helpers on a fresh copy of the two files.
Future<Directory> _relocate(String applicationId) async {
  final root = Directory.systemTemp.createTempSync('setup_main_activity_');
  for (final relative in [_activity, _activityTest]) {
    File('${root.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync(File(relative).readAsStringSync());
  }
  File(
    'bricks/flutter_starter_setup/hooks/input_rules.dart',
  ).copySync('${root.path}/input_rules.dart');
  final probe = File('${root.path}/post_gen_probe.dart')
    ..writeAsStringSync('''
${File(_hookPath).readAsStringSync()}
Future<void> main(List<String> args) async {
  final logger = Logger();
  await _relocateMainActivity(args[0], args[1], logger);
  await _relocateMainActivityTest(args[0], args[1], logger);
}
''');
  final result = await Process.run('dart', [
    '--packages=${File('.dart_tool/package_config.json').absolute.path}',
    probe.path,
    root.path,
    applicationId,
  ]);
  if (result.exitCode != 0) {
    fail('hook failed: ${result.stdout}\n${result.stderr}');
  }
  return root;
}

void main() {
  final skip = _skipReason();

  for (final id in [
    'com.example.flutter_starter',
    'com.example.flutter_starter.dev',
    'com.acme.shop',
  ]) {
    test('application_id $id keeps both entry points in its package', () async {
      final root = await _relocate(id);
      addTearDown(() => root.deleteSync(recursive: true));
      final dir = id.replaceAll('.', '/');

      final activity = File(
        '${root.path}/android/app/src/main/kotlin/$dir/MainActivity.kt',
      );
      expect(activity.existsSync(), isTrue, reason: activity.path);
      expect(
        activity.readAsStringSync(),
        matches(RegExp('^package ${RegExp.escape(id)}\$', multiLine: true)),
      );

      final activityTest = File(
        '${root.path}/android/app/src/androidTest/java/$dir/'
        'MainActivityTest.java',
      );
      expect(activityTest.existsSync(), isTrue, reason: activityTest.path);
      expect(
        activityTest.readAsStringSync(),
        matches(RegExp('^package ${RegExp.escape(id)};\$', multiLine: true)),
      );

      // Exactly one copy of each, so nothing is left behind at the old path.
      for (final name in ['MainActivity.kt', 'MainActivityTest.java']) {
        final copies = Directory('${root.path}/android')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last == name);
        expect(copies, hasLength(1), reason: name);
      }

      // A different id leaves the template package empty, so it goes.
      if (!id.startsWith('com.example.flutter_starter')) {
        for (final sourceRoot in [
          'android/app/src/main/kotlin',
          'android/app/src/androidTest/java',
        ]) {
          expect(
            Directory('${root.path}/$sourceRoot/com/example').existsSync(),
            isFalse,
            reason: sourceRoot,
          );
        }
      }
    }, skip: skip);
  }
}
