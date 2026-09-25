// Cache age is a duration between two absolute instants, so the stored
// timestamp has to name an instant - not a wall clock reading whose meaning
// depends on the offset the reader happens to be in.
//
// Regression cover for koniz-dev/flutter-starter#188. Before the fix,
// `_cacheResponse` stored `DateTime.now().toIso8601String()` on a *local*
// DateTime, which emits neither `Z` nor a numeric offset, and
// `_getCachedResponse` read it back with `DateTime.parse`, which reads a
// missing designator as local. Round tripping in one zone is lossless, which
// is why this shipped; the moment the device's offset moves between the write
// and the read the age is wrong by the difference, so fresh entries are
// evicted in one direction and stale ones are served past `maxStale` in the
// other.
//
// The simulation trick used throughout: this process cannot change its own
// timezone, so a differing offset is simulated on the *writer* side instead.
// A device at `hostOffset + 7h` writing instant T produces exactly the digits
// `T.add(7h).toIso8601String()` produces here. That is equivalent to the
// reader having moved by -7h, and it is portable: it holds whatever the host
// zone actually is, including UTC (as on CI).
//
// Counterfactual, actually run against the pre-fix `cache_interceptor.dart`
// (docs/verification/issue-188/counterfactual.log): 5 of these 12 tests fail,
// including the end-to-end cross-zone one, which reports the age a reader
// seven hours away computes for an entry written seconds earlier as 7:00:00.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real in-memory StorageService, so the tests assert on what was actually
/// persisted rather than on which mock method happened to be called.
class _InMemoryStorage implements StorageService {
  final Map<String, Object?> values = {};

  @override
  Future<void> init() async {}

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    values[key] = value;
    return true;
  }

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      values[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    values[key] = value;
    return true;
  }
}

class _CapturingRequestHandler extends RequestInterceptorHandler {
  Response<dynamic>? resolvedResponse;

  bool get servedFromCache => resolvedResponse != null;

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingResponseInterceptor = true,
  ]) {
    resolvedResponse = response;
  }
}

const String _cacheKey = 'http_cache_https://api.example.com/api/test_{}';
const String _timestampKey = 'http_cache_timestamp_$_cacheKey';
const String _indexKey = 'http_cache_index';
const String _body = '{"key":"value"}';

RequestOptions _getRequest() => RequestOptions(
  path: '/api/test',
  method: 'GET',
  baseUrl: 'https://api.example.com',
);

/// An ISO-8601 string for [instant] as a writer sitting at [offset] would
/// emit it: wall-clock digits in that zone, followed by the numeric offset.
///
/// All of these denote the same instant, so every reader must agree on the
/// age they imply, wherever the reader is.
String _isoWithOffset(DateTime instant, Duration offset) {
  final shifted = instant.toUtc().add(offset);
  final digits = shifted.toIso8601String().replaceFirst('Z', '');
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hh = abs.inHours.toString().padLeft(2, '0');
  final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return '$digits$sign$hh:$mm';
}

/// The string the pre-fix code wrote on a device whose offset is [zoneShift]
/// away from this process's: wall-clock digits, no designator.
String _offsetLessAtShiftedZone(DateTime instant, Duration zoneShift) =>
    instant.add(zoneShift).toIso8601String();

/// The age a reader whose UTC offset is [readerShift] away from this
/// process's would compute for [stored] at instant [now].
///
/// This is the other half of the simulation: a string carrying a designator
/// parses to the same instant everywhere, so the reader's zone drops out; a
/// string without one is read as the reader's own wall clock, so it lands
/// [readerShift] away from where it was written.
Duration _ageComputedByReaderShiftedBy(
  Duration readerShift,
  String stored,
  DateTime now,
) {
  final parsed = DateTime.parse(stored);
  final instant = parsed.isUtc ? parsed : parsed.subtract(readerShift);
  return now.toUtc().difference(instant);
}

void main() {
  late _InMemoryStorage storage;

  setUp(() {
    storage = _InMemoryStorage();
  });

  CacheInterceptor buildInterceptor({
    Duration maxAge = const Duration(minutes: 10),
    Duration maxStale = const Duration(minutes: 20),
  }) => CacheInterceptor(
    storageService: storage,
    cacheConfig: CacheConfig(maxAge: maxAge, maxStale: maxStale),
  );

  void seedEntry(String timestamp) {
    storage.values[_cacheKey] = _body;
    storage.values[_timestampKey] = timestamp;
    storage.values[_indexKey] = <String>[_cacheKey];
  }

  Future<bool> readIsServed(CacheInterceptor interceptor) async {
    final handler = _CapturingRequestHandler();
    await interceptor.onRequest(_getRequest(), handler);
    return handler.servedFromCache;
  }

  // The host offset is part of the evidence: criterion 2 asks for a run under
  // a non-UTC TZ, and this group name lands in the test log verbatim.
  group(
    'CacheInterceptor timestamps (host UTC offset '
    '${DateTime.now().timeZoneOffset})',
    () {
      group('criterion 1 - the written timestamp names an instant', () {
        test('stored timestamp carries a Z designator', () async {
          final interceptor = buildInterceptor();
          final request = _getRequest();
          final response = Response<dynamic>(
            data: {'key': 'value'},
            statusCode: 200,
            requestOptions: request,
          );

          await interceptor.onResponse(response, ResponseInterceptorHandler());

          final stored = storage.values[_timestampKey]! as String;
          expect(
            stored,
            matches(RegExp(r'(Z|[+-]\d{2}:\d{2})$')),
            reason: 'an offset-less string means whatever zone reads it',
          );
          expect(DateTime.parse(stored).isUtc, isTrue);
        });

        test('stored timestamp is the write instant, not shifted by the host '
            'offset', () async {
          final interceptor = buildInterceptor();
          final before = DateTime.now().toUtc();

          await interceptor.onResponse(
            Response<dynamic>(
              data: {'key': 'value'},
              statusCode: 200,
              requestOptions: _getRequest(),
            ),
            ResponseInterceptorHandler(),
          );

          final stored = DateTime.parse(
            storage.values[_timestampKey]! as String,
          ).toUtc();
          final after = DateTime.now().toUtc();
          expect(
            stored.isBefore(before.subtract(const Duration(seconds: 5))),
            isFalse,
            reason: 'a host-offset shift would land hours outside this window',
          );
          expect(
            stored.isAfter(after.add(const Duration(seconds: 5))),
            isFalse,
            reason: 'a host-offset shift would land hours outside this window',
          );
        });
      });

      group(
        'criterion 2 - an N-minute-old entry ages as N minutes in either '
        'string form',
        () {
          test('both forms are evicted when N exceeds maxStale', () async {
            final writtenAt = DateTime.now().subtract(
              const Duration(minutes: 30),
            );

            seedEntry(DateFormatter.formatIso8601(writtenAt));
            expect(await readIsServed(buildInterceptor()), isFalse);

            seedEntry(writtenAt.toIso8601String()); // legacy, offset-less
            expect(
              await readIsServed(buildInterceptor()),
              isFalse,
              reason: 'an entry already on disk must not change age at upgrade',
            );
          });

          test('both forms are served when N is inside maxAge', () async {
            final writtenAt = DateTime.now().subtract(
              const Duration(minutes: 5),
            );

            seedEntry(DateFormatter.formatIso8601(writtenAt));
            expect(await readIsServed(buildInterceptor()), isTrue);

            seedEntry(writtenAt.toIso8601String()); // legacy, offset-less
            expect(await readIsServed(buildInterceptor()), isTrue);
          });

          test('both forms are served, not deleted, while N is between maxAge '
              'and maxStale', () async {
            final writtenAt = DateTime.now().subtract(
              const Duration(minutes: 15),
            );

            for (final timestamp in <String>[
              DateFormatter.formatIso8601(writtenAt),
              writtenAt.toIso8601String(),
            ]) {
              seedEntry(timestamp);
              expect(await readIsServed(buildInterceptor()), isTrue);
              expect(storage.values.containsKey(_cacheKey), isTrue);
            }
          });
        },
      );

      group('criterion 3 - the age does not depend on the zone', () {
        test('every zone spelling of one instant yields the same eviction '
            'decision', () async {
          final writtenAt = DateTime.now().subtract(
            const Duration(minutes: 30),
          );
          const zones = <Duration>[
            Duration.zero,
            Duration(hours: 7),
            Duration(hours: -5),
            Duration(hours: 5, minutes: 30),
            Duration(hours: -11),
            Duration(hours: 13),
          ];

          for (final zone in zones) {
            seedEntry(_isoWithOffset(writtenAt, zone));
            expect(
              await readIsServed(buildInterceptor()),
              isFalse,
              reason: 'a 30-minute-old entry is past maxStale in zone $zone',
            );

            seedEntry(_isoWithOffset(writtenAt, zone));
            expect(
              await readIsServed(
                buildInterceptor(maxAge: const Duration(hours: 1)),
              ),
              isTrue,
              reason: 'the same entry is inside a 1h maxAge in zone $zone',
            );
          }
        });

        test('an entry written before a 7-hour zone change is still aged '
            'correctly', () async {
          final writtenAt = DateTime.now().subtract(
            const Duration(minutes: 30),
          );
          const zoneShift = Duration(hours: 7);

          // What the fix writes, from any device, for that instant.
          seedEntry(DateFormatter.formatIso8601(writtenAt));
          expect(
            await readIsServed(buildInterceptor()),
            isFalse,
            reason: '30 minutes old is past a 20-minute maxStale',
          );

          // The same entry written by the pre-fix code on a device seven
          // hours away: the digits alone claim an instant 7h off.
          final legacy = _offsetLessAtShiftedZone(writtenAt, zoneShift);
          expect(
            DateTime.parse(legacy).difference(writtenAt),
            zoneShift,
            reason: 'this is the error an offset-less string carries',
          );
          seedEntry(legacy);
          expect(
            await readIsServed(buildInterceptor()),
            isTrue,
            reason:
                'documented cost of a legacy entry: it reads 6.5h in the '
                'future and is served past maxStale until it is rewritten',
          );
        });

        test('a reader in another zone computes the same age for what the '
            'interceptor just wrote', () async {
          final interceptor = buildInterceptor();
          await interceptor.onResponse(
            Response<dynamic>(
              data: {'key': 'value'},
              statusCode: 200,
              requestOptions: _getRequest(),
            ),
            ResponseInterceptorHandler(),
          );
          final stored = storage.values[_timestampKey]! as String;
          final writtenAt = DateTime.now();

          for (final readerShift in <Duration>[
            Duration.zero,
            const Duration(hours: 7),
            const Duration(hours: -5),
            const Duration(hours: 1), // the DST case
          ]) {
            final age = _ageComputedByReaderShiftedBy(
              readerShift,
              stored,
              writtenAt,
            );
            expect(
              age.abs(),
              lessThan(const Duration(seconds: 5)),
              reason:
                  'an entry written seconds ago must not be '
                  '${age.inHours}h old to a reader $readerShift away',
            );
          }
        });

        test('the reverse shift makes a fresh legacy entry look expired, '
            'while the Z form does not', () async {
          final writtenAt = DateTime.now().subtract(const Duration(minutes: 5));
          const zoneShift = Duration(hours: -7);

          seedEntry(DateFormatter.formatIso8601(writtenAt));
          expect(await readIsServed(buildInterceptor()), isTrue);

          seedEntry(_offsetLessAtShiftedZone(writtenAt, zoneShift));
          expect(
            await readIsServed(buildInterceptor()),
            isFalse,
            reason: 'a 5-minute-old entry read as 7h05m old is thrown away',
          );
        });
      });

      group('criterion 4 - a timestamp with no meaning is a miss', () {
        test('an unparseable timestamp is a cache miss and the entry is '
            'dropped', () async {
          seedEntry('not-a-timestamp');

          expect(await readIsServed(buildInterceptor()), isFalse);
          expect(storage.values.containsKey(_cacheKey), isFalse);
          expect(storage.values.containsKey(_timestampKey), isFalse);
          expect(storage.values.containsKey(_indexKey), isFalse);
        });

        test('an out-of-range calendar date is a cache miss, not a nearby '
            'date', () async {
          // February has no 30th. DateTime.parse rolls this over to 2
          // March 2099 and answers a plausible-looking - here, negative -
          // age, so the corrupt entry is served forever.
          seedEntry('2099-02-30T00:00:00.000Z');

          expect(await readIsServed(buildInterceptor()), isFalse);
          expect(storage.values.containsKey(_cacheKey), isFalse);
          expect(storage.values.containsKey(_timestampKey), isFalse);
        });

        test('an entry dropped for a corrupt timestamp is refetched and '
            'rewritten in the new form', () async {
          final interceptor = buildInterceptor();
          seedEntry('2024-13-45T00:00:00.000Z');

          expect(await readIsServed(interceptor), isFalse);

          await interceptor.onResponse(
            Response<dynamic>(
              data: {'key': 'value'},
              statusCode: 200,
              requestOptions: _getRequest(),
            ),
            ResponseInterceptorHandler(),
          );

          expect(storage.values[_timestampKey]! as String, endsWith('Z'));
          expect(await readIsServed(interceptor), isTrue);
        });
      });
    },
  );
}
