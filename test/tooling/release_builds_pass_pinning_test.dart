// Pinning is on in staging and production, and a release built with pinning
// on and no fingerprints refuses to start. No build path the starter shipped
// passed API_SSL_FINGERPRINTS, so each one built an app that would not open.
// Every mobile release build command under scripts/ and .github/workflows/ -
// the commented deploy templates included, since adopters uncomment them -
// must now carry the pinning defines from scripts/ci/ssl_pinning_defines.sh.
//
// Web builds are exempt: the browser owns TLS, pinning never applies there,
// and the app does not refuse a web release.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _build = RegExp(r'flutter build (apk|appbundle|ipa|ios)\b');

/// Every `flutter build` command in [file] for a mobile target, joined across
/// its `\` continuations, with YAML comment markers removed. A command inside
/// a sentence (a backtick, an echo) is not a command.
List<String> _mobileBuilds(File file) {
  final lines = file
      .readAsLinesSync()
      .map((l) => l.replaceFirst(RegExp(r'^\s*#\s?'), '').trimRight())
      .toList();
  final commands = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimLeft();
    if (!line.startsWith('flutter build') || !_build.hasMatch(line)) continue;
    final command = StringBuffer(line);
    var j = i;
    while (lines[j].endsWith(r'\') && j + 1 < lines.length) {
      j++;
      command.write(' ${lines[j].trim()}');
    }
    commands.add(command.toString());
  }
  return commands;
}

void main() {
  final files = [
    for (final dir in ['scripts', '.github/workflows'])
      ...Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.sh') || f.path.endsWith('.yml')),
  ];

  test('the scan finds the release builds it should', () {
    final found = {
      for (final f in files)
        if (_mobileBuilds(f).isNotEmpty) f.path.replaceAll(r'\', '/'),
    };
    expect(
      found,
      containsAll([
        'scripts/ci/build_all.sh',
        '.github/workflows/build.yml',
        '.github/workflows/deploy-android.yml',
        '.github/workflows/deploy-ios.yml',
      ]),
    );
  });

  test('every mobile release build carries the pinning defines', () {
    final missing = <String>[
      for (final f in files)
        for (final command in _mobileBuilds(f))
          if (!command.contains('--debug') &&
              !command.contains('--profile') &&
              !command.contains('DEFINES[@]'))
            '${f.path}: $command',
    ];
    expect(missing, isEmpty);
  });

  test('every file with such a build calls the pinning guard', () {
    final unguarded = <String>[
      for (final f in files)
        if (_mobileBuilds(f).any((c) => c.contains('DEFINES[@]')) &&
            !RegExp(
              r'^\s*#?\s*(if !\s*)?ssl_pinning_defines "',
              multiLine: true,
            ).hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(unguarded, isEmpty);
  });

  group('ssl_pinning_defines.sh validates what the app parses', () {
    // The app trims each comma-separated entry at its ends and drops colons
    // (AppConfig.apiSslFingerprints), then matches a SHA-256 exactly. The
    // helper deleted every space and grepped per line, so a value the app can
    // never match passed and the release refused every connection.
    final hex = 'ab' * 32;

    ProcessResult defines(String fingerprints) => Process.runSync(
      'bash',
      [
        '-c',
        '. scripts/ci/ssl_pinning_defines.sh && ssl_pinning_defines production',
      ],
      environment: {
        'API_SSL_FINGERPRINTS': fingerprints,
        'ENABLE_SSL_PINNING': '',
      },
    );

    test('a fingerprint, trimmed or colon-separated, is accepted', () {
      for (final value in [
        hex,
        '  $hex\n',
        List.generate(32, (_) => 'AB').join(':'),
        '$hex, ${'cd' * 32}',
      ]) {
        final result = defines(value);
        expect(result.exitCode, 0, reason: '$value: ${result.stderr}');
      }
    });

    test('a space-separated fingerprint is refused', () {
      final result = defines(List.filled(32, 'ab').join(' '));
      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('is not a SHA-256'));
    });

    test('a fingerprint with a line break inside is refused', () {
      final result = defines('garbage\n$hex');
      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('is not a SHA-256'));
    });
  });
}
