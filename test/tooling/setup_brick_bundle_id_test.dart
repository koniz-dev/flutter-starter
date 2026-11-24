// The setup brick writes ios_bundle_id into every iOS and macOS bundle-id
// site, and turns a bare `com.example` into the organization taken from
// application_id. When the bundle id itself starts with `com.example`, the
// organization rule must not then rewrite the bundle id it has just written,
// or fastlane and the export options name an app that does not exist.
//
// As in setup_brick_main_activity_test.dart, the hook source is compiled into
// a probe so its private iOS helper runs unchanged, on copies of the files.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _hookPath = 'bricks/flutter_starter_setup/hooks/post_gen.dart';
const _iosBundleId = 'com.example.myApp';

const _files = [
  'ios/Runner.xcodeproj/project.pbxproj',
  'macos/Runner.xcodeproj/project.pbxproj',
  'macos/Runner/Configs/AppInfo.xcconfig',
  'ios/ExportOptions.plist',
  'ios/fastlane/Appfile',
  'fastlane/Appfile',
  'linux/CMakeLists.txt',
];

/// Android ids to pair with [_iosBundleId]: one in another organization, and
/// one whose organization itself starts with `com.example`.
const _applicationIds = ['com.acme.shop', 'com.example.acme.shop'];

String? _skipReason() {
  if (!File(_hookPath).existsSync()) return 'the setup brick has been removed';
  for (final relative in _files) {
    if (!File(relative).existsSync()) return '$relative is missing';
  }
  if (!File(_files.first).readAsStringSync().contains(
    'com.example.flutterStarter',
  )) {
    return 'the iOS bundle id has already been renamed';
  }
  return null;
}

void main() {
  final skip = _skipReason();
  late Directory base;

  setUpAll(() async {
    if (skip != null) return;
    base = Directory.systemTemp.createTempSync('setup_bundle_id_');
    for (var i = 0; i < _applicationIds.length; i++) {
      for (final relative in _files) {
        File('${base.path}/$i/$relative')
          ..createSync(recursive: true)
          ..writeAsStringSync(File(relative).readAsStringSync());
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
    await _patchIosBundleIds(root, '$_iosBundleId', logger);
    await patchPlatformIdentifiers(
      rootPath: root,
      packageName: 'acme_shop',
      applicationId: args[i],
      iosBundleId: '$_iosBundleId',
      appDisplayName: 'Acme Shop',
      logger: logger,
    );
  }
}
''');
    final result = await Process.run('dart', [
      '--packages=${File('.dart_tool/package_config.json').absolute.path}',
      probe.path,
      base.path,
      ..._applicationIds,
    ]);
    if (result.exitCode != 0) {
      fail('hook failed: ${result.stdout}\n${result.stderr}');
    }
  });

  tearDownAll(() {
    if (skip == null && base.existsSync()) base.deleteSync(recursive: true);
  });

  List<String> values(String text, String pattern) => RegExp(
    pattern,
    multiLine: true,
  ).allMatches(text).map((m) => m[1]!).toList();

  for (var i = 0; i < _applicationIds.length; i++) {
    final applicationId = _applicationIds[i];
    group('ios_bundle_id $_iosBundleId with application_id $applicationId', () {
      String read(String relative) =>
          File('${base.path}/$i/$relative').readAsStringSync();

      for (final pbxproj in _files.take(2)) {
        test('every PRODUCT_BUNDLE_IDENTIFIER in $pbxproj', () {
          final ids = values(
            read(pbxproj),
            'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
          );
          expect(ids, isNotEmpty);
          expect(
            ids,
            everyElement(
              anyOf(_iosBundleId, '$_iosBundleId.RunnerTests'),
            ),
          );
        }, skip: skip);
      }

      test('macOS AppInfo.xcconfig', () {
        expect(
          values(
            read('macos/Runner/Configs/AppInfo.xcconfig'),
            r'^PRODUCT_BUNDLE_IDENTIFIER = (.+)$',
          ),
          [_iosBundleId],
        );
      }, skip: skip);

      test('the ExportOptions.plist provisioning profile key', () {
        expect(
          values(
            read('ios/ExportOptions.plist'),
            r'<key>provisioningProfiles</key>\s*<dict>\s*<key>([^<]+)</key>',
          ),
          [_iosBundleId],
        );
      }, skip: skip);

      test('the iOS fastlane Appfile app_identifier', () {
        expect(
          values(read('ios/fastlane/Appfile'), r'^app_identifier\("([^"]+)"\)'),
          [_iosBundleId],
        );
      }, skip: skip);

      test('the Android ids keep application_id', () {
        expect(
          values(read('fastlane/Appfile'), r'^package_name\("([^"]+)"\)'),
          [applicationId],
        );
        expect(
          values(
            read('linux/CMakeLists.txt'),
            r'^set\(APPLICATION_ID "([^"]+)"\)',
          ),
          [applicationId],
        );
      }, skip: skip);
    });
  }
}
