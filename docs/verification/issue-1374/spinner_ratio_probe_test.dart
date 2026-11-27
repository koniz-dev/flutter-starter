// The app-bar spinner on the tasks screens is the only sign a load or save is
// in flight. It sits on the app bar, so it has to stand out against the app
// bar's own colour, not the scaffold's: WCAG 1.4.11 asks 3:1 of a graphical
// object a user needs to perceive.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/core/accessibility/accessibility_helpers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

void main() {
  final themes = {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  };
  final screens = <String, Widget>{
    'tasks list': const TasksListScreen(),
    'task detail': const TaskDetailScreen(),
  };

  for (final MapEntry(key: themeName, value: theme) in themes.entries) {
    for (final MapEntry(key: screenName, value: screen) in screens.entries) {
      testWidgets(
        '$themeName theme, $screenName: the app-bar spinner reads against '
        'the app bar',
        (tester) async {
          // Hold the load open so the spinner stays up.
          final pending = Completer<Result<List<Task>>>();
          final getAllTasks = _MockGetAllTasksUseCase();
          when(getAllTasks.call).thenAnswer((_) => pending.future);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
              ],
              child: MaterialApp(
                theme: theme,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: LocalizationService.supportedLocales,
                home: screen,
              ),
            ),
          );
          await tester.pump();

          final spinnerFinder = find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(CircularProgressIndicator),
          );
          expect(spinnerFinder, findsOneWidget);
          final spinnerElement = tester.element(spinnerFinder);
          final spinner = tester.widget<CircularProgressIndicator>(
            spinnerFinder,
          );
          // The colour the indicator paints with when none is passed.
          final spinnerColor =
              spinner.valueColor?.value ??
              spinner.color ??
              ProgressIndicatorTheme.of(spinnerElement).color ??
              Theme.of(spinnerElement).colorScheme.primary;

          final appBarMaterial = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(AppBar),
                  matching: find.byType(Material),
                )
                .first,
          );
          final appBarColor = appBarMaterial.color!;

          final ratio = AccessibilityHelpers.getContrastRatio(spinnerColor, appBarColor);
          // ignore: avoid_print
          print('RATIO $themeName / $screenName: spinner ${spinnerColor.toARGB32().toRadixString(16)} on app bar ${appBarColor.toARGB32().toRadixString(16)} = ${ratio.toStringAsFixed(2)}:1');
          expect(
            ratio,
            greaterThanOrEqualTo(AccessibilityConstants.minContrastRatioLarge),
            reason: 'spinner $spinnerColor on app bar $appBarColor',
          );

          pending.complete(const Success<List<Task>>([]));
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
