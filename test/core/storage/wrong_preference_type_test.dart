import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnreadableLegacyStorage extends StorageService {
  @override
  Future<String?> getString(String key) async {
    if (key == 'user_tags') {
      throw const CacheException('Read unavailable', code: 'STORE_READ_FAILED');
    }
    return super.getString(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final value in <Object>[
    42,
    true,
    1.5,
    <String>['preserve me'],
  ]) {
    test('wrong preference type: ${value.runtimeType} reports storage failure '
        'without deleting the value', () async {
      SharedPreferences.setMockInitialValues({'value': value});
      final storage = StorageService();
      await expectLater(
        storage.getString('value'),
        throwsA(isA<CacheException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('value'), value);
      expect(await storage.setString('value', 'repaired'), isTrue);
      expect(await storage.getString('value'), 'repaired');
    });
  }

  test(
    'migration preserves schema and legacy data on other read failures',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageVersion.versionKey: '1',
        'user_tags': 'original,tags',
      });
      final storage = _UnreadableLegacyStorage();
      await expectLater(
        MigrationV1ToV2().execute(storage),
        throwsA(
          isA<CacheException>().having(
            (error) => error.code,
            'code',
            'STORE_READ_FAILED',
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(StorageVersion.versionKey), '1');
      expect(prefs.get('user_tags'), 'original,tags');
    },
  );

  testWidgets(
    'wrong preference type: tasks shows a recoverable storage error',
    (
      tester,
    ) async {
      const original = <String>['preserve me'];
      SharedPreferences.setMockInitialValues({'tasks_data': original});
      final storage = StorageService();
      await tester.runAsync(storage.init);
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TasksListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      final state = container.read(tasksNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.failure, isA<CacheFailure>());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final l10n = AppLocalizationsEn();
      expect(find.text(l10n.failureStorage), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);

      final now = DateTime(2026);
      final created = await container
          .read(tasksRepositoryProvider)
          .createTask(
            Task(id: 'new', title: 'New task', createdAt: now, updatedAt: now),
          );
      expect(created.failureOrNull, isA<CacheFailure>());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('tasks_data'), original);

      await tester.runAsync(() => storage.setString('tasks_data', '[]'));
      await container.read(tasksNotifierProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(container.read(tasksNotifierProvider).isLoading, isFalse);
      expect(container.read(tasksNotifierProvider).failure, isNull);
      expect(find.text(l10n.failureStorage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
