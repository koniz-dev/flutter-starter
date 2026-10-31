// create_feature.ps1 title-cased the feature name with the current culture,
// so under a Turkish culture `i` became a dotted capital I and the generated
// class names were not valid Dart identifiers. It now uses the invariant
// culture for every identifier.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('scripts/dev/create_feature.ps1').readAsStringSync();

  test('identifiers are cased with the invariant culture', () {
    expect(
      script,
      contains('[System.Globalization.CultureInfo]::InvariantCulture'),
    );
    expect(script, isNot(contains('Get-Culture')));
    expect(script, isNot(contains('CurrentCulture')));
    // ToLower()/ToUpper() without an argument use the current culture.
    expect(script, isNot(contains('.ToLower()')));
    expect(script, isNot(contains('.ToUpper()')));
  });
}
