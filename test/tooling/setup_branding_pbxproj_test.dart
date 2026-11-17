// flutter_launcher_icons 0.13.1 rewrites every Xcode build-setting line that
// mentions ASSETCATALOG to `= AppIcon;`, so setup_branding.sh silently turned
// ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS off. The script
// now puts it back. This runs the real script against a stub `dart` that
// makes the same rewrite. The stub must start with its shebang.
// ignore_for_file: leading_newlines_in_multiline_strings
@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _stubDart = r'''#!/usr/bin/env bash
if [ "$2" = "flutter_launcher_icons" ]; then
  perl -pi -e 's/(ASSETCATALOG\w* = ).*;/${1}AppIcon;/' \
    ios/Runner.xcodeproj/project.pbxproj
fi
exit 0
''';

void main() {
  const setting =
      'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS';

  test('branding leaves the Swift asset-symbol setting at YES', () {
    final dir = Directory.systemTemp.createTempSync('branding_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bin = Directory('${dir.path}/bin')..createSync();
    final dart = File('${bin.path}/dart')..writeAsStringSync(_stubDart);
    Process.runSync('chmod', ['+x', dart.path]);
    Directory('${dir.path}/scripts/dev').createSync(recursive: true);
    File(
      'scripts/dev/setup_branding.sh',
    ).copySync('${dir.path}/scripts/dev/setup_branding.sh');
    File('${dir.path}/assets/images/logo.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0]);
    final original = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final pbxproj = File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
      ..createSync(recursive: true)
      ..writeAsStringSync(original);

    final result = Process.runSync(
      'bash',
      ['scripts/dev/setup_branding.sh'],
      workingDirectory: dir.path,
      environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
    );

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final after = pbxproj.readAsStringSync();
    expect(after, isNot(contains('$setting = AppIcon;')));
    expect(
      '$setting = YES;'.allMatches(after),
      hasLength('$setting = YES;'.allMatches(original).length),
    );
    expect('${result.stdout}', isNot(contains('tailored for iOS, Android')));
  });
}
