// DisposalTracker.dispose ran its disposables in one loop and stopped at the
// first that threw: the rest were never disposed and super.dispose() never
// ran.

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/memory_helper.dart';
import 'package:flutter_test/flutter_test.dart';

final List<String> _log = [];

class _Tracked extends StatefulWidget {
  const _Tracked();

  @override
  State<_Tracked> createState() => _TrackedState();
}

class _TrackedState extends State<_Tracked> with DisposalTracker<_Tracked> {
  @override
  void initState() {
    super.initState();
    registerDisposable(() => _log.add('first'));
    registerDisposable(() => throw StateError('second failed'));
    registerDisposable(() => _log.add('third'));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('a throwing disposable does not stop the others or '
      'super.dispose()', (tester) async {
    _log.clear();
    await tester.pumpWidget(const _Tracked());
    final state = tester.state<_TrackedState>(find.byType(_Tracked));

    await tester.pumpWidget(const SizedBox());

    expect(_log, ['first', 'third']);
    expect(state.mounted, isFalse, reason: 'super.dispose() ran');
    expect(tester.takeException(), isA<StateError>());
  });
}
