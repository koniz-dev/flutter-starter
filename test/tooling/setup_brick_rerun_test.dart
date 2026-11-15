@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const hookPath = 'bricks/flutter_starter_setup/hooks/pre_gen.dart';
  final skip = !File(hookPath).existsSync()
      ? 'the setup brick has been removed'
      : null;

  for (final state in ['fresh', 'renamed', 'android-only', 'ios-only']) {
    test('setup pre_gen checks $state project before writing', () async {
      final root = Directory.systemTemp.createTempSync('setup_rerun_');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String path, String value) {
        File('${root.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(value);
      }

      write(
        'pubspec.yaml',
        'name: ${state == 'renamed' ? 'acme_shop' : 'flutter_starter'}\n',
      );
      final androidId = state == 'renamed' || state == 'android-only'
          ? 'io.acme.shop.app'
          : 'com.example.flutter_starter';
      write('android/app/build.gradle.kts', '''
android {
    namespace = "$androidId"
    defaultConfig { applicationId = "$androidId" }
}
''');
      final iosId = state == 'renamed' || state == 'ios-only'
          ? 'io.acme.shop.app'
          : 'com.example.flutterStarter';
      write('ios/Runner.xcodeproj/project.pbxproj', '''
PRODUCT_BUNDLE_IDENTIFIER = $iosId;
PRODUCT_BUNDLE_IDENTIFIER = $iosId.RunnerTests;
''');
      write('run_pre_gen.dart', '''
import 'package:mason/mason.dart';
import '${File(hookPath).absolute.uri}' as hook;
class Context implements HookContext {
  @override
  Map<String, dynamic> vars = {
    'package_name': 'zeta_two',
    'application_id': 'org.zeta.two',
    'ios_bundle_id': 'org.zeta.two',
    'app_display_name': 'Zeta Two',
  };
  @override
  final Logger logger = Logger();
}
void main() => hook.run(Context());
''');
      Future<ProcessResult> git(List<String> args) =>
          Process.run('git', args, workingDirectory: root.path);
      expect((await git(['init', '-q'])).exitCode, 0);
      expect(
        (await git([
          'add',
          'pubspec.yaml',
          'android',
          'ios',
          'run_pre_gen.dart',
        ])).exitCode,
        0,
      );
      expect(
        (await git([
          '-c',
          'user.name=Test',
          '-c',
          'user.email=test@example.invalid',
          '-c',
          'core.hooksPath=${root.path}/no-hooks',
          '-c',
          'commit.gpgsign=false',
          'commit',
          '-qm',
          'fixture',
        ])).exitCode,
        0,
      );

      final result = await Process.run('dart', [
        '--packages=${File('.dart_tool/package_config.json').absolute.path}',
        '${root.path}/run_pre_gen.dart',
      ], workingDirectory: root.path);
      final output = '${result.stdout}${result.stderr}';
      if (state == 'fresh') {
        expect(result.exitCode, 0, reason: output);
      } else {
        expect(result.exitCode, isNot(0), reason: output);
        expect(output, contains('already customized'));
        expect(output, contains('fork-and-customize.md'));
        expect(output, isNot(contains('Renamed')));
        expect(output, isNot(contains('Updated')));
        expect(output, isNot(contains('Setup complete')));
      }
      final status = await git(['status', '--porcelain']);
      expect(status.exitCode, 0);
      expect(
        status.stdout,
        isEmpty,
        reason: 'pre_gen must leave every tracked file unchanged',
      );
    }, skip: skip);
  }
}
