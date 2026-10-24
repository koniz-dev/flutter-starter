// Every AppConfig knob must be read by something outside the config layer.
//
// API_SEND_TIMEOUT and API_TIMEOUT were documented, parsed, exposed as
// AppConfig getters and unit-tested - and read by nothing, so setting them did
// nothing. A getter test only proves a knob
// parses. This one proves each knob is wired: it fails when an AppConfig
// getter that reads the environment is referenced by no file in lib/ outside
// lib/core/config/. Derived predicates such as `isStaging` are not knobs and
// are not scanned.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _appConfigPath = 'lib/core/config/app_config.dart';

/// Knobs known to be unread, each with why it is unread. The scan fails
/// if one of these gains a reader, so the entry is removed with the fix.
const Map<String, String> _knownUnread = {
  // Documented as "Reserved, not wired".
  'enableAnalytics': 'reserved, not wired',
  'enableCrashReporting': 'reserved, not wired',
};

/// Knobs whose only readers live in a sample feature that
/// `tool/strip_sample_features.dart` can delete. In a tree stripped of that
/// feature the knob is legitimately unread, so it is not scanned there - the
/// same rule `enable_toggles_have_readers_test.dart` applies. None today:
/// `enableDebugFeatures` is read by the route registry, in every variant.
const Map<String, String> _readOnlyByStrippableFeature = {};

/// Every `static <Type> get <name>` declared on AppConfig.
final RegExp _getter = RegExp(r'static\s+[\w<>?, ]+\s+get\s+(\w+)\s*(?:=>|\{)');

/// The getters among [source]'s declarations whose body reads the
/// environment - the configurable knobs.
Set<String> _knobs(String source) {
  final matches = _getter.allMatches(source).toList();
  return {
    for (var i = 0; i < matches.length; i++)
      if (source
          .substring(
            matches[i].start,
            i + 1 < matches.length ? matches[i + 1].start : source.length,
          )
          .contains('EnvConfig.'))
        matches[i].group(1)!,
  };
}

void main() {
  final knobs = _knobs(File(_appConfigPath).readAsStringSync());

  final consumers = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.startsWith('lib/core/config/'))
      .expand((f) => f.readAsLinesSync())
      // A doc comment naming a getter is not a read.
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  bool isRead(String name) =>
      RegExp('AppConfig\\.$name\\b').hasMatch(consumers);

  bool readerStripped(String name) {
    final feature = _readOnlyByStrippableFeature[name];
    return feature != null && !Directory(feature).existsSync();
  }

  test('the scan sees the environment-backed getters', () {
    // Guards the parsing: if the declaration style changes, this fails
    // instead of the scans below passing vacuously.
    expect(knobs, containsAll(['apiSendTimeout', 'apiTimeout', 'baseUrl']));
    expect(knobs, isNot(contains('isStaging')));
  });

  test('every AppConfig knob is read outside lib/core/config/', () {
    final unread = [
      for (final name in knobs.toList()..sort())
        if (!isRead(name) &&
            !_knownUnread.containsKey(name) &&
            !readerStripped(name))
          name,
    ];

    expect(
      unread,
      isEmpty,
      reason:
          'These AppConfig knobs are read by nothing outside '
          'lib/core/config/, so setting them has no effect. Wire each one, '
          'or remove it from AppConfig, DartDefines, .env.example and the '
          'docs together: $unread',
    );
  });

  test('the known-unread list holds only knobs that are still unread', () {
    final stale = [
      for (final MapEntry(key: name, value: why) in _knownUnread.entries)
        if (!knobs.contains(name) || isRead(name)) '$name ($why)',
    ];

    expect(
      stale,
      isEmpty,
      reason: 'Remove these from _knownUnread: they are wired or gone: $stale',
    );
  });
}
