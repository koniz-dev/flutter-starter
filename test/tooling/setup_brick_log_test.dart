@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Whether this tree is still the unrenamed starter. The setup brick renames
/// only that, and a manual rename (fork-and-customize.md, Option B) also
/// rewrites the template ids in this file's fixtures, but not in the brick's
/// hooks, which it leaves alone: the tests would compare two different ids.
bool _unrenamedStarter() => RegExp(
  r'^name: flutter_starter\s*$',
  multiLine: true,
).hasMatch(File('pubspec.yaml').readAsStringSync());

void main() {
  const hookPath = 'bricks/flutter_starter_setup/hooks/post_gen.dart';
  test(
    'package and iOS rename logs describe actual changes only',
    () async {
      final root = Directory.systemTemp.createTempSync('setup_logs_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/pubspec.yaml')
          .writeAsStringSync('name: flutter_starter\n');
      final project = File('${root.path}/ios/Runner.xcodeproj/project.pbxproj')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter;\n',
        );
      File('bricks/flutter_starter_setup/hooks/input_rules.dart')
          .copySync('${root.path}/input_rules.dart');
      // Compile the real hook in its own library so its private helpers can be
      // exercised without making test-only APIs part of the brick.
      final probe = File('${root.path}/post_gen_probe.dart')
        ..writeAsStringSync('''
${File(hookPath).readAsStringSync()}
Future<void> main(List<String> args) async {
  final root = args.single;
  final logger = Logger();
  await _renameDartPackage(root, 'flutter_starter', logger);
  await _patchIosBundleIds(root, 'com.example.flutterStarter', logger);
  stdout.writeln('NOOP-DONE');
  await _renameDartPackage(root, 'acme_shop', logger);
  await _patchIosBundleIds(root, 'io.acme.shop.app', logger);
}
''');
      final result = await Process.run('dart', [
        '--packages=${File('.dart_tool/package_config.json').absolute.path}',
        probe.path,
        root.path,
      ]);
      final output = '${result.stdout}${result.stderr}';
      expect(result.exitCode, 0, reason: output);
      final segments = output.split('NOOP-DONE');
      expect(segments, hasLength(2));
      expect(segments.first, isNot(contains('Renamed')));
      expect(segments.first, isNot(contains('Updated')));
      expect(segments.last, contains('Renamed Dart package to acme_shop'));
      expect(
        segments.last,
        contains('Updated iOS PRODUCT_BUNDLE_IDENTIFIER to io.acme.shop.app'),
      );
      expect(
        File('${root.path}/pubspec.yaml').readAsStringSync(),
        'name: acme_shop\n',
      );
      expect(
        project.readAsStringSync(),
        'PRODUCT_BUNDLE_IDENTIFIER = io.acme.shop.app;\n',
      );
    },
    skip: !File(hookPath).existsSync()
        ? 'the setup brick has been removed'
        : !_unrenamedStarter()
        ? 'the project is renamed; the setup brick no longer applies'
        : null,
  );
}
