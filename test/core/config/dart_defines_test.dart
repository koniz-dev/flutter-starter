import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/dart_defines.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skip reason for the groups that read source files through dart:io, which
/// a browser does not have. Everything else in this file runs on web too.
const String? _readsSourceFiles = kIsWeb
    ? 'reads source files through dart:io; run on the VM'
    : null;

/// Strips `//` and `///` comment lines so prose that mentions
/// `String.fromEnvironment` is not mistaken for a call site.
String _stripLineComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Every `fromEnvironment` call site in [source], as the first character of
/// its argument list (whitespace skipped).
List<String> _fromEnvironmentArgumentStarts(String source) {
  final pattern = RegExp(r'\.fromEnvironment\(\s*(\S)', dotAll: true);
  return pattern
      .allMatches(source)
      .map((m) => m.group(1)!)
      .toList(growable: false);
}

Iterable<File> _dartFilesUnder(String directory) =>
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

/// Keys declared in `.env.example`, i.e. lines of the form `KEY=` or `KEY=v`.
Set<String> _envExampleKeys() {
  final pattern = RegExp('^([A-Z][A-Z0-9_]*)=');
  return File('.env.example')
      .readAsLinesSync()
      .map((line) => pattern.firstMatch(line.trim())?.group(1))
      .whereType<String>()
      .toSet();
}

/// Literal keys passed to `EnvConfig.get*`/`EnvConfig.has` anywhere in `lib/`.
Set<String> _keysReadFromLib() {
  final pattern = RegExp(
    r"EnvConfig\.(?:get|getBool|getInt|getDouble|has)\(\s*'([A-Z][A-Z0-9_]*)'",
  );
  final keys = <String>{};
  for (final file in _dartFilesUnder('lib')) {
    final source = _stripLineComments(file.readAsStringSync());
    for (final match in pattern.allMatches(source)) {
      keys.add(match.group(1)!);
    }
  }
  return keys;
}

void main() {
  group('DartDefines', () {
    test('lookup returns the compile-time value for a known key', () {
      // Equals the const read of the same key: '' when no --dart-define was
      // passed, the supplied value when one was.
      expect(
        DartDefines.lookup('BASE_URL'),
        const String.fromEnvironment('BASE_URL'),
      );
      expect(DartDefines.isKnown('BASE_URL'), isTrue);
    });

    test('lookup returns the empty string for an unknown key', () {
      expect(DartDefines.lookup('NOT_A_REAL_KEY'), isEmpty);
      expect(DartDefines.isKnown('NOT_A_REAL_KEY'), isFalse);
    });

    test('values is a compile-time constant map (unmodifiable at runtime)', () {
      // A `const` map is canonicalised and immutable; a plain map literal
      // would accept this write. This is what makes the table resolvable in
      // AOT builds.
      expect(
        () => DartDefines.values['BASE_URL'] = 'mutated',
        throwsUnsupportedError,
      );
      expect(identical(DartDefines.values, DartDefines.values), isTrue);
    });
  });

  group('dart-define mechanism', () {
    // Criterion 3: assert the mechanism, not the value. The JIT VM used by
    // `flutter test` can resolve a non-const `String.fromEnvironment`, so a
    // value-based test would pass even with the AOT-broken runtime form.
    test('every fromEnvironment call in lib/ takes a string literal', () {
      final offenders = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        final source = _stripLineComments(file.readAsStringSync());
        for (final start in _fromEnvironmentArgumentStarts(source)) {
          if (start != "'" && start != '"') {
            offenders.add('${file.path}: argument starts with `$start`');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A fromEnvironment call with a non-literal argument cannot be '
            'const and always returns "" in AOT builds. Add the key to '
            'DartDefines.values instead.',
      );
    });

    test('env_config.dart contains no fromEnvironment call at all', () {
      final source = _stripLineComments(
        File('lib/core/config/env_config.dart').readAsStringSync(),
      );
      expect(source, contains('DartDefines.lookup('));
      expect(
        _fromEnvironmentArgumentStarts(source),
        isEmpty,
        reason:
            'EnvConfig must read dart-defines through the const DartDefines '
            'table, never directly.',
      );
    });

    test('dart_defines.dart declares the table as const', () {
      final source = _stripLineComments(
        File('lib/core/config/dart_defines.dart').readAsStringSync(),
      );
      expect(
        source,
        contains('static const Map<String, String> values'),
        reason: 'The table must be const or the entries resolve to "" in AOT.',
      );
    });

    test('no dart-define read is skipped on web', () {
      // dart2js resolves the const table like every other compiler, so web
      // needs no guard. Every read here used to sit behind `if (!kIsWeb)`,
      // and a web build discarded each --dart-define it was given.
      final source = _stripLineComments(
        File('lib/core/config/env_config.dart').readAsStringSync(),
      );
      expect(source, isNot(contains('kIsWeb')));
      expect(
        RegExp(r'DartDefines\.lookup\(').allMatches(source).length,
        2,
        reason: 'get and has each consult it',
      );
      // The typed getters parse what get() resolves, so they inherit its
      // dart-define fallback rather than each carrying their own.
      for (final getter in ['getBool', 'getInt', 'getDouble']) {
        final body = RegExp(
          'static \\w+ $getter\\([^)]*\\)[^;{]*(\\{[^}]*\\}|=>[^;]*;)',
        ).firstMatch(source)?.group(0);
        expect(body, isNotNull, reason: '$getter not found');
        expect(body, contains('get(key)'), reason: getter);
      }
    });
  }, skip: _readsSourceFiles);

  group('key coverage', () {
    test('every .env.example key has a DartDefines entry', () {
      final missing = _envExampleKeys().difference(
        DartDefines.values.keys.toSet(),
      );
      expect(
        missing,
        isEmpty,
        reason:
            'These keys are documented in .env.example but cannot be supplied '
            'via --dart-define. Add them to DartDefines.values.',
      );
    });

    test('every DartDefines entry is documented in .env.example', () {
      final undocumented = DartDefines.values.keys.toSet().difference(
        _envExampleKeys(),
      );
      expect(undocumented, isEmpty);
    });

    test('ENVIRONMENT and BASE_URL are covered', () {
      expect(DartDefines.values, contains('ENVIRONMENT'));
      expect(DartDefines.values, contains('BASE_URL'));
    });

    test('every key EnvConfig is asked for in lib/ has an entry', () {
      final keysRead = _keysReadFromLib();
      expect(keysRead, isNotEmpty, reason: 'scanner found no call sites');
      expect(keysRead.difference(DartDefines.values.keys.toSet()), isEmpty);
    });
  }, skip: _readsSourceFiles);

  group('end-to-end with a supplied --dart-define', () {
    // Only exercised when the suite is run as
    //   flutter test --dart-define=BASE_URL=https://api.example.com
    // Skipped otherwise, because the value is baked in at compile time and
    // cannot be injected from inside the test.
    //
    // Also run it on web:
    //   flutter test --platform chrome \
    //     --dart-define=BASE_URL=https://api.example.com \
    //     test/core/config/dart_defines_test.dart
    // The source-scanning groups above read files with dart:io and are
    // skipped there.
    final suppliedBaseUrl = DartDefines.lookup('BASE_URL');
    final skipReason = suppliedBaseUrl.isEmpty
        ? 'run with --dart-define=BASE_URL=<url> to exercise this'
        : null;

    test(
      'BASE_URL reaches EnvConfig and AppConfig',
      () {
        expect(EnvConfig.get('BASE_URL'), suppliedBaseUrl);
        expect(AppConfig.baseUrl, suppliedBaseUrl);
        expect(AppConfig.baseUrl, isNot('http://localhost:3000'));
      },
      skip: skipReason,
    );

    // With pinning requested through dart-defines, web must not report
    // itself as pinned: the browser owns TLS, and the
    // defines do reach a web build. Run as
    //   flutter test [--platform chrome] --dart-define=ENABLE_SSL_PINNING=true \
    //     --dart-define=API_SSL_FINGERPRINTS=<sha256> \
    //     test/core/config/dart_defines_test.dart
    final pinningSupplied =
        DartDefines.lookup('ENABLE_SSL_PINNING').isNotEmpty &&
        DartDefines.lookup('API_SSL_FINGERPRINTS').isNotEmpty;

    test(
      'pinning defines reach AppConfig, and web never reports pinning '
      'effective',
      () {
        expect(AppConfig.enableSslPinning, isTrue);
        expect(AppConfig.apiSslFingerprints, isNotEmpty);
        expect(AppConfig.sslPinningEffective, !kIsWeb);
        expect(AppConfig.sslPinningMisconfigured, isFalse);
      },
      skip: pinningSupplied
          ? null
          : 'run with --dart-define=ENABLE_SSL_PINNING=true and '
                'API_SSL_FINGERPRINTS=<sha256> to exercise this',
    );
  });
}
