// Each task row's checkbox was its own unlabeled semantics node, announced as
// a bare "checkbox", and its menu as the generic "Show menu": a screen reader
// user could not tell which task either one acted on. The row also used
// Colors.grey and Colors.red, below WCAG AA; it now takes theme colours that
// the contrast suite checks.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';

class _GetAllTasks extends Mock implements GetAllTasksUseCase {}

Future<void> _pumpTasks(WidgetTester tester, {ThemeData? theme}) async {
  final getAll = _GetAllTasks();
  when(getAll.call).thenAnswer(
    (_) async => Success<List<Task>>([
      createTask(id: 'a', title: 'Buy milk'),
      createTask(id: 'b', title: 'Call Ana', isCompleted: true),
    ]),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [getAllTasksUseCaseProvider.overrideWithValue(getAll)],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: const TasksListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the checkbox and the menu of a row name its task', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpTasks(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));

    for (final (index, title) in [(0, 'Buy milk'), (1, 'Call Ana')]) {
      final checkbox = tester.getSemantics(find.byType(Checkbox).at(index));
      expect(checkbox.label, title, reason: 'checkbox of row $index');

      final menu = tester.getSemantics(
        find.descendant(
          of: find.byType(PopupMenuButton<String>).at(index),
          matching: find.byType(IconButton),
        ),
      );
      expect(menu.tooltip, l10n.taskActions(title), reason: 'row $index');
    }
    semantics.dispose();
  });

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('$name: a completed row, Delete and its confirmation use '
        'theme colours', (tester) async {
      await _pumpTasks(tester, theme: theme);
      final colors = theme.colorScheme;

      final completed = tester.widget<Text>(find.text('Call Ana'));
      expect(completed.style?.color, colors.onSurfaceVariant);
      final open = tester.widget<Text>(find.text('Buy milk'));
      expect(open.style?.color, isNot(colors.onSurfaceVariant));

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        tester.widget<Text>(find.text(l10n.delete)).style?.color,
        colors.error,
      );

      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();
      final confirm = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, l10n.delete),
      );
      expect(
        confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
        colors.onError,
      );
      expect(
        confirm.style?.backgroundColor?.resolve(<WidgetState>{}),
        colors.error,
      );
    });
  }
}
