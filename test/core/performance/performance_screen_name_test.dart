// The default screen name replaced every "State" in the widget's type name,
// so a screen called StatementScreen was traced as "mentScreen".

import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_screen_mixin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => StatementScreenState();
}

class StatementScreenState extends State<StatementScreen>
    with PerformanceScreenMixin {
  @override
  IPerformanceService? get performanceService => null;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('a "State" inside the screen name is kept', (tester) async {
    await tester.pumpWidget(const StatementScreen());

    final state = tester.state<StatementScreenState>(
      find.byType(StatementScreen),
    );
    expect(state.screenName, 'StatementScreen');
  });
}
