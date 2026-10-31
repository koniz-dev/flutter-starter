// The setup brick wrote app_display_name into the Android manifest, the iOS
// Info.plist, pubspec's patrol block and the Fastfiles unescaped, so a name
// such as "Salt & Pepper" produced files that no longer parse while mason
// reported success. This runs the hook's own patch functions on copies of
// those files and parses each result.
//
// As in setup_brick_feature_rename_test.dart, the hook runs in a `dart`
// subprocess so that deleting bricks/ does not break analysis, and the file
// skips when there is no brick or the package was already renamed.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _hookPath = 'bricks/flutter_starter_setup/hooks/post_gen.dart';
const _name = 'Tom & "Jerry": #1 <\'x\'> \\ #{oops}';

const _files = [
  'android/app/src/main/AndroidManifest.xml',
  'ios/Runner/Info.plist',
  'pubspec.yaml',
  'fastlane/Fastfile',
  'ios/fastlane/Fastfile',
];

String? _skipReason() {
  if (!File(_hookPath).existsSync()) return 'bricks/ has been removed';
  final named = RegExp(r'^name:\s*flutter_starter\s*$', multiLine: true);
  if (!named.hasMatch(File('pubspec.yaml').readAsStringSync())) {
    return 'the package has already been renamed by the setup brick';
  }
  return null;
}

ProcessResult _run(String exe, List<String> args) => Process.runSync(exe, args);

bool _has(String exe) {
  try {
    return Process.runSync(exe, ['--version']).exitCode == 0 ||
        Process.runSync('which', [exe]).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  final skip = _skipReason();
  late Directory root;

  setUpAll(() async {
    if (skip != null) return;
    root = Directory.systemTemp.createTempSync('setup_brick_display_name_');
    for (final relative in _files) {
      File('${root.path}/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync(File(relative).readAsStringSync());
    }
    final hook = File(_hookPath).absolute.uri;
    final script = File('${root.path}/run_hook.dart')
      ..writeAsStringSync(
        "import 'package:mason/mason.dart';\n"
        "import '$hook' as hook;\n"
        'Future<void> main(List<String> args) async {\n'
        '  final root = args[0];\n'
        '  final name = args[1];\n'
        '  final logger = Logger();\n'
        '  await hook.patchAndroidManifest(root, name);\n'
        "  await hook.patchPatrolConfig(root, 'com.acme.shop', name, logger);\n"
        '  await hook.patchPlatformIdentifiers(\n'
        '    rootPath: root,\n'
        "    packageName: 'acme_shop',\n"
        "    applicationId: 'com.acme.shop',\n"
        "    iosBundleId: 'com.acme.shop',\n"
        '    appDisplayName: name,\n'
        '    logger: logger,\n'
        '  );\n'
        '}\n',
      );
    final packages = File('.dart_tool/package_config.json').absolute.path;
    final result = await Process.run('dart', [
      '--packages=$packages',
      script.path,
      root.path,
      _name,
    ]);
    if (result.exitCode != 0) {
      fail('hook failed: ${result.stdout}\n${result.stderr}');
    }
  });

  tearDownAll(() {
    if (skip == null && root.existsSync()) root.deleteSync(recursive: true);
  });

  String read(String relative) =>
      File('${root.path}/$relative').readAsStringSync();

  test('the AndroidManifest parses and carries the name', () {
    final path = '${root.path}/${_files[0]}';
    final lint = _run('xmllint', ['--noout', path]);
    expect(lint.exitCode, 0, reason: '${lint.stderr}');
    final label = _run('xmllint', [
      '--xpath',
      'string(//*[local-name()="application"]/@*[local-name()="label"])',
      path,
    ]);
    expect('${label.stdout}'.replaceFirst(RegExp(r'\n$'), ''), _name);
  }, skip: skip ?? (_has('xmllint') ? null : 'xmllint is not installed'));

  test('the Info.plist parses and carries the name', () {
    final path = '${root.path}/${_files[1]}';
    final lint = _run('xmllint', ['--noout', path]);
    expect(lint.exitCode, 0, reason: '${lint.stderr}');
    final value = _run('xmllint', [
      '--xpath',
      'string(//key[.="CFBundleDisplayName"]/following-sibling::string[1])',
      path,
    ]);
    expect('${value.stdout}'.replaceFirst(RegExp(r'\n$'), ''), _name);
    if (Platform.isMacOS) {
      final plutil = _run('plutil', ['-lint', path]);
      expect(plutil.exitCode, 0, reason: '${plutil.stdout}');
    }
  }, skip: skip ?? (_has('xmllint') ? null : 'xmllint is not installed'));

  test("pubspec's patrol app_name parses back to the name", () {
    final yaml = loadYaml(read('pubspec.yaml')) as YamlMap;
    expect((yaml['patrol'] as YamlMap)['app_name'], _name);
  }, skip: skip);

  for (final fastfile in _files.sublist(3)) {
    test('$fastfile APP_NAME evaluates to the name', () {
      final line = RegExp(
        r'^\s*APP_NAME = .*$',
        multiLine: true,
      ).firstMatch(read(fastfile))!.group(0)!;
      final ruby = _run('ruby', ['-e', '$line\nprint APP_NAME']);
      expect(ruby.exitCode, 0, reason: '${ruby.stderr}');
      expect('${ruby.stdout}', _name);
    }, skip: skip ?? (_has('ruby') ? null : 'ruby is not installed'));
  }
}
