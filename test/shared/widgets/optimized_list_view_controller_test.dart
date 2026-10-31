// OptimizedListView picked its ScrollController in initState and had no
// didUpdateWidget, so a controller passed or swapped after the first build
// was ignored: it had no clients, prefetch kept listening to the old one,
// and an internally created controller was never disposed.

// The tests read ChangeNotifier.hasListeners, which is protected.
// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/widgets/optimized_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

final List<String> _items = [for (var i = 0; i < 100; i++) 'Item $i'];

Widget _list(ScrollController? controller, {VoidCallback? onLoadMore}) =>
    MaterialApp(
      home: Scaffold(
        body: OptimizedListView<String>(
          items: _items,
          scrollController: controller,
          hasMore: true,
          onLoadMore: onLoadMore == null
              ? null
              : () async {
                  onLoadMore();
                  return (<String>[], true);
                },
          itemBuilder: (context, item, index) =>
              SizedBox(height: 50, child: Text(item)),
        ),
      ),
    );

ScrollController _listController(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).controller!;

void main() {
  testWidgets('a controller passed after the first build drives the list and '
      'prefetch', (tester) async {
    var loads = 0;
    await tester.pumpWidget(_list(null, onLoadMore: () => loads++));
    final external = ScrollController();
    addTearDown(external.dispose);

    await tester.pumpWidget(_list(external, onLoadMore: () => loads++));

    expect(external.hasClients, isTrue);
    external.jumpTo(external.position.maxScrollExtent);
    await tester.pump();
    expect(loads, greaterThan(0), reason: 'prefetch listens to the new one');
  });

  testWidgets('an internally created controller is disposed when replaced', (
    tester,
  ) async {
    await tester.pumpWidget(_list(null));
    final internal = _listController(tester);
    final external = ScrollController();
    addTearDown(external.dispose);

    await tester.pumpWidget(_list(external));

    expect(
      () => internal.addListener(() {}),
      throwsFlutterError,
      reason: 'a disposed ChangeNotifier refuses new listeners',
    );
  });

  testWidgets('a swapped-out controller loses the prefetch listener', (
    tester,
  ) async {
    final first = ScrollController();
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(_list(first, onLoadMore: () {}));
    expect(first.hasListeners, isTrue);

    await tester.pumpWidget(_list(second, onLoadMore: () {}));

    expect(first.hasListeners, isFalse);
    expect(second.hasClients, isTrue);
  });
}
