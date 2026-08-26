// TEMPORARY PROBE for issue #40 - not a shipped test. Removed before merge.
//
// Question: does `pumpAndSettle` time out on a real device because of the LIVE
// binding's frame policy (which deliberately pumps extra frames), or because
// something in the app schedules frames forever?
//
// Binary experiment: run the same pumpAndSettle under both policies.
//   onlyPumps settles + fadePointers times out -> the binding is the cause.
//   both time out                              -> the app is the cause.
import 'package:flutter/widgets.dart';
import 'package:flutter_starter/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

Future<void> _probe(PatrolIntegrationTester $, String label) async {
  await app.main();
  await $.pump(const Duration(seconds: 1));
  try {
    await $.tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 25),
    );
    // Printing is the point: this is a probe whose only output is the verdict
    // in the CI log.
    // ignore: avoid_print
    print('PROBE-40 $label: SETTLED');
  } on Object catch (e) {
    // Printing is the point: see above.
    // ignore: avoid_print
    print('PROBE-40 $label: TIMED OUT -> $e');
  }
}

void main() {
  patrolTest('probe: framePolicy onlyPumps', ($) async {
    (WidgetsBinding.instance as LiveTestWidgetsFlutterBinding).framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
    await _probe($, 'onlyPumps');
  });

  patrolTest('probe: framePolicy fadePointers (Patrol default)', ($) async {
    (WidgetsBinding.instance as LiveTestWidgetsFlutterBinding).framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;
    await _probe($, 'fadePointers');
  });
}
