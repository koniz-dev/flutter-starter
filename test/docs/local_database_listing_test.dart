// storage.md lists the ILocalDatabase interface an implementation must
// satisfy. The listing once had five of its eight members (no saveAll,
// delete or clear), so a class written from the doc did not compile. Every
// member the source declares must be in the listing, as declared.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `Future<...> name...;` member signatures in [text], trimmed.
Set<String> _members(String text) => RegExp(
  r'^\s*(Future<.+;)\s*$',
  multiLine: true,
).allMatches(text).map((m) => m.group(1)!.trim()).toSet();

void main() {
  test('storage.md lists every ILocalDatabase member as declared', () {
    final source = File('lib/core/storage/local_database.dart')
        .readAsStringSync();
    final doc = File('docs/api/core/storage.md').readAsStringSync();
    final listing = doc.substring(
      doc.indexOf('abstract class ILocalDatabase'),
      doc.indexOf('```', doc.indexOf('abstract class ILocalDatabase')),
    );

    expect(_members(source), hasLength(8));
    expect(_members(listing), _members(source));
  });
}
