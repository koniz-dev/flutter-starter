// fastlane/ssl_pinning.rb is the Fastfiles' copy of the pinning rules in
// scripts/ci/ssl_pinning_defines.sh. These run it through `ruby` for each
// case, so the Ruby port is pinned and not only argued.

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

/// `SslPinning.defines(environment, fingerprints:, pinning:)`, or
/// `REFUSED: <message>`.
String _defines(String environment, String? fingerprints, String? pinning) {
  final result = Process.runSync('ruby', [
    '-e',
    '''
require File.expand_path("fastlane/ssl_pinning")
env, fp, pin = ARGV
fp = nil if fp == "<nil>"
pin = nil if pin == "<nil>"
begin
  print SslPinning.defines(env, fingerprints: fp, pinning: pin)
rescue ArgumentError => e
  print "REFUSED: #{e.message}"
end
''',
    environment,
    fingerprints ?? '<nil>',
    pinning ?? '<nil>',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return '${result.stdout}';
}

void main() {
  final fp = 'ab' * 32;
  final skip = _hasRuby ? null : 'ruby is not installed';

  test('staging and production without fingerprints are refused', () {
    for (final env in ['staging', 'production']) {
      expect(_defines(env, null, null), startsWith('REFUSED: '), reason: env);
      expect(_defines(env, ' , ', null), startsWith('REFUSED: '), reason: env);
      expect(_defines(env, '', null), startsWith('REFUSED: '), reason: env);
    }
  }, skip: skip);

  test('valid fingerprints pass through as a define', () {
    final colons = List.filled(32, 'AB').join(':');
    expect(
      _defines('production', '$colons,${'cd' * 32}', null),
      contains('API_SSL_FINGERPRINTS'),
    );
    expect(_defines('production', '$fp\r\n', null), contains(fp));
  }, skip: skip);

  test('a fingerprint that is not 64 hex digits is refused anywhere', () {
    for (final env in ['development', 'production']) {
      expect(
        _defines(env, 'AA:BB', null),
        contains('is not a SHA-256'),
        reason: env,
      );
    }
  }, skip: skip);

  test('a space-separated fingerprint is refused, as the app could never '
      'match it', () {
    expect(
      _defines('production', List.filled(32, 'ab').join(' '), null),
      startsWith('REFUSED: '),
    );
  }, skip: skip);

  test('a fingerprint with a line break inside is refused', () {
    expect(
      _defines('production', 'garbage\n$fp', null),
      startsWith('REFUSED: '),
    );
    expect(
      _defines('production', '${'ab' * 16}\n${'ab' * 16}', null),
      startsWith('REFUSED: '),
    );
  }, skip: skip);

  test('an entry is trimmed at its ends, as the app trims it', () {
    expect(
      _defines('production', '  $fp\r\n', null),
      contains('API_SSL_FINGERPRINTS'),
    );
  }, skip: skip);

  test('the opt-out values the app reads as false build without '
      'fingerprints', () {
    for (final value in ['false', 'FALSE', '0', 'no', 'off', ' off ']) {
      expect(
        _defines('production', null, value),
        contains('ENABLE_SSL_PINNING'),
        reason: value,
      );
    }
  }, skip: skip);

  test('a value that is not an opt-out is still refused', () {
    for (final value in ['true', 'enabled', 'flase']) {
      expect(
        _defines('production', null, value),
        startsWith('REFUSED: '),
        reason: value,
      );
    }
  }, skip: skip);

  test('an unrecognised flag is refused even with fingerprints', () {
    for (final value in ['enabled', ' ', 'ture']) {
      expect(
        _defines('production', fp, value),
        contains('neither on'),
        reason: '"$value"',
      );
    }
  }, skip: skip);

  test('development passes through with nothing set', () {
    expect(_defines('development', null, null), isEmpty);
  }, skip: skip);
}
