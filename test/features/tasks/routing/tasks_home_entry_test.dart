import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/features/tasks/routing/tasks_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/signed_in_app.dart';

void main() {
  testWidgets('home opens the tasks list, and back returns home', (
    tester,
  ) async {
    await pumpSignedInApp(tester);

    await tester.tap(
      find.byKey(UiKeys.homeDestination(tasksHomeDestination.id)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TasksListScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
