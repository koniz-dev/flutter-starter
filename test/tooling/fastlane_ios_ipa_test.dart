// The iOS lanes and the commented App Store upload step assumed
// build/ios/ipa/Runner.ipa, but Xcode names the exported IPA after the app's
// product name, which follows the bundle name rather than the Runner target.
// fastlane/ios_ipa.rb takes the one .ipa the export wrote, whatever it is
// called, and the lanes clear earlier exports first so a stale one cannot be
// picked.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final bool _hasRuby = () {
  try {
    return Process.runSync('ruby', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// Runs [code] in Ruby with fastlane/ios_ipa.rb loaded.
String _ruby(String code) {
  final result = Process.runSync('ruby', [
    '-e',
    'require File.expand_path("fastlane/ios_ipa"); $code',
  ]);
  return '${result.stdout}${result.stderr}';
}

void main() {
  final skip = _hasRuby ? null : 'ruby is not installed';
  late Directory root;
  late Directory export;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ios_ipa_');
    export = Directory('${root.path}/build/ios/ipa')
      ..createSync(recursive: true);
  });
  tearDown(() => root.deleteSync(recursive: true));

  String find() => _ruby(
    'begin; print IosIpa.find("${root.path}"); '
    'rescue ArgumentError => e; print "refused: #{e.message}"; end',
  );

  test('the one exported IPA is found, whatever it is called', () {
    File('${export.path}/flutter_starter.ipa').writeAsStringSync('ipa');

    expect(find(), '${export.path}/flutter_starter.ipa');
  }, skip: skip);

  test('no IPA is refused, naming the directory', () {
    expect(find(), startsWith('refused: No IPA found in'));
  }, skip: skip);

  test('more than one IPA is refused, naming them', () {
    File('${export.path}/Runner.ipa').writeAsStringSync('old');
    File('${export.path}/my_app.ipa').writeAsStringSync('new');

    expect(find(), contains('found 2: Runner.ipa, my_app.ipa'));
  }, skip: skip);

  test('clear removes earlier exports', () {
    File('${export.path}/Runner.ipa').writeAsStringSync('old');

    _ruby('IosIpa.clear("${root.path}")');

    expect(export.existsSync(), isFalse);
  }, skip: skip);

  test('no lane or upload step names Runner.ipa', () {
    for (final path in [
      'ios/fastlane/Fastfile',
      '.github/workflows/deploy-ios.yml',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('Runner.ipa')),
        reason: path,
      );
    }
    final fastfile = File('ios/fastlane/Fastfile').readAsStringSync();
    expect(
      'IosIpa.clear('.allMatches(fastfile),
      hasLength(2),
      reason: 'both build lanes clear earlier exports',
    );
  });
}
