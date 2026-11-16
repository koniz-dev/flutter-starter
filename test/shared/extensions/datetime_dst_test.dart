// isYesterday and isTomorrow compared against now minus or plus 24 hours,
// which is not a calendar day around a daylight-saving change: in
// America/New_York at 00:30 on 10 March 2025, 24 hours earlier is 23:30 on
// 8 March. The local time zone is fixed per process, so the check runs in a
// `dart` subprocess with TZ set.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_starter/shared/extensions/datetime_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

const _script = '''
import 'package:flutter_starter/shared/extensions/datetime_extensions.dart';

void main() {
  final afterSpringForward = DateTime(2025, 3, 10, 0, 30);
  final beforeSpringForward = DateTime(2025, 3, 8, 23, 30);
  print([
    DateTime(2025, 3, 9).isYesterdayRelativeTo(afterSpringForward),
    DateTime(2025, 3, 8).isYesterdayRelativeTo(afterSpringForward),
    DateTime(2025, 3, 9).isTomorrowRelativeTo(beforeSpringForward),
    DateTime(2025, 3, 10).isTomorrowRelativeTo(beforeSpringForward),
  ].join(','));
}
''';

const _utcScript = r'''
import 'package:flutter_starter/shared/extensions/datetime_extensions.dart';
void main() {
  final utc = DateTime.utc(2024, 1, 15, 20);
  final local = utc.toLocal();
  final localYesterday = DateTime(local.year, local.month, local.day - 1);
  final localTomorrow = DateTime(local.year, local.month, local.day + 1);
  final results = [
    utc.startOfDay.isUtc,
    utc.endOfDay.isUtc,
    utc.startOfDay == DateTime.utc(2024, 1, 15),
    utc.endOfDay == DateTime.utc(2024, 1, 15, 23, 59, 59, 999),
    !utc.isBefore(utc.startOfDay) && !utc.isAfter(utc.endOfDay),
    DateTime.utc(2024, 1, 14).isYesterdayRelativeTo(local),
    DateTime.utc(2024, 1, 16).isTomorrowRelativeTo(local),
    localYesterday.isYesterdayRelativeTo(utc),
    localTomorrow.isTomorrowRelativeTo(utc),
    DateTime.now().toUtc().isToday,
  ];
  print('${local.timeZoneOffset.inHours}|' + results.join(','));
}
''';

void main() {
  for (final entry in const {
    'Asia/Ho_Chi_Minh': 7,
    'Pacific/Kiritimati': 14,
    'Etc/GMT+12': -12,
  }.entries) {
    test('UTC receiver semantics in ${entry.key}', () {
      final dir = Directory.systemTemp.createTempSync('datetime_utc_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final script = File('${dir.path}/utc.dart')
        ..writeAsStringSync(_utcScript);
      final packages = File('.dart_tool/package_config.json').absolute.path;
      final result = Process.runSync(
        'dart',
        ['--packages=$packages', script.path],
        environment: {'TZ': entry.key},
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      // Keep the actual offset and results in the regression evidence.
      // ignore: avoid_print
      print('TZ=${entry.key}: ${result.stdout}');
      expect(
        '${result.stdout}'.trim(),
        '${entry.value}|${List.filled(10, true).join(',')}',
      );
    });
  }

  test('yesterday and tomorrow are calendar days across a DST change', () {
    final dir = Directory.systemTemp.createTempSync('datetime_dst_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final script = File('${dir.path}/dst.dart')..writeAsStringSync(_script);
    final packages = File('.dart_tool/package_config.json').absolute.path;

    final result = Process.runSync(
      'dart',
      ['--packages=$packages', script.path],
      environment: {'TZ': 'America/New_York'},
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect('${result.stdout}'.trim(), 'true,false,true,false');
  });

  test('the getters still answer for the current day', () {
    final now = DateTime.now();
    expect(DateTime(now.year, now.month, now.day - 1).isYesterday, isTrue);
    expect(DateTime(now.year, now.month, now.day + 1).isTomorrow, isTrue);
    expect(now.isYesterday, isFalse);
  });
}
