// The app keeps the device's region, not only its language.
//
// deviceLocale() and a stored language choice both resolved to the region
// hard-coded in SupportedLocale (en_US, es_ES), and MaterialApp's default
// resolution mapped any requested en_GB onto en_US as well, so a UK device
// read 9 March as 3/9/2026 and an es_MX device was shown euros.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/main.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(id: '1', email: 'test@example.com'),
  );
}

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

final DateTime _ninthOfMarch = DateTime(2026, 3, 9);

/// Boots the real [MyApp] on [device] with [stored] preferences, signed in,
/// and opens the tasks list holding one task created on 9 March 2026.
Future<ProviderContainer> _pumpTasksList(
  WidgetTester tester, {
  required List<Locale> device,
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  tester.platformDispatcher.localesTestValue = device;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final getAllTasks = _MockGetAllTasksUseCase();
  when(getAllTasks.call).thenAnswer(
    (_) async => Success<List<Task>>([
      Task(
        id: 'a',
        title: 'Alpha',
        createdAt: _ninthOfMarch,
        updatedAt: _ninthOfMarch,
      ),
    ]),
  );
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_SignedIn.new),
      sessionRestorationProvider.overrideWith((ref) async {}),
      getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  container.read(goRouterProvider).go(AppRoutes.tasks);
  await tester.pumpAndSettle(const Duration(seconds: 5));
  expect(find.byType(TasksListScreen), findsOneWidget);
  return container;
}

Locale _screenLocale(WidgetTester tester) =>
    Localizations.localeOf(tester.element(find.byType(TasksListScreen)));

class _MapStorage implements StorageService {
  _MapStorage([Map<String, String>? values]) : _values = {...?values};

  final Map<String, String> _values;

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('criterion 1: no stored choice follows the device region', () {
    testWidgets('an en_GB device reports en_GB and a British date', (
      tester,
    ) async {
      await _pumpTasksList(tester, device: const [Locale('en', 'GB')]);

      expect(_screenLocale(tester), const Locale('en', 'GB'));
      expect(find.text('09/03/2026'), findsOneWidget);
      expect(find.text('3/9/2026'), findsNothing);
    });

    test('deviceLocale keeps the region of the first matching locale', () {
      expect(
        LocalizationService.deviceLocale(const [Locale('en', 'GB')]),
        const Locale('en', 'GB'),
      );
      expect(
        LocalizationService.deviceLocale(const [Locale('es', 'MX')]),
        const Locale('es', 'MX'),
      );
      expect(
        LocalizationService.deviceLocale(const [
          Locale('fr', 'FR'),
          Locale('en', 'AU'),
        ]),
        const Locale('en', 'AU'),
      );
      // A language with no region keeps the entry's default one.
      expect(
        LocalizationService.deviceLocale(const [Locale('en')]),
        SupportedLocale.en.locale,
      );
    });

    test('an es_MX device is shown pesos, not euros', () {
      final locale = LocalizationService.deviceLocale(const [
        Locale('es', 'MX'),
      ]);
      final shown = LocalizedFormatters.formatCurrency(10, locale: locale);
      expect(shown, contains(r'$'));
      expect(shown, isNot(contains('€')));
    });
  });

  group('criterion 2: a stored language keeps the device region', () {
    testWidgets('stored en on an en_GB device stays en_GB', (tester) async {
      await _pumpTasksList(
        tester,
        device: const [Locale('en', 'GB')],
        stored: const {'language': 'en'},
      );

      expect(_screenLocale(tester), const Locale('en', 'GB'));
      expect(find.text('09/03/2026'), findsOneWidget);
    });

    testWidgets('getCurrentLocale restores the device region', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [
        Locale('vi', 'VN'),
        Locale('en', 'GB'),
      ];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final service = LocalizationService(
        storageService: _MapStorage({'language': 'en'}),
      );

      expect(await service.getCurrentLocale(), const Locale('en', 'GB'));
    });

    testWidgets('a stored language the device does not list keeps its '
        'default region', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final service = LocalizationService(
        storageService: _MapStorage({'language': 'es'}),
      );

      expect(await service.getCurrentLocale(), SupportedLocale.es.locale);
    });
  });

  group('the language picker on a regional locale', () {
    testWidgets('marks the current language and applies the device region', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final container = ProviderContainer(
        overrides: [
          localizationServiceProvider.overrideWithValue(
            LocalizationService(storageService: _MapStorage()),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(localeStateProvider.notifier).locale = const Locale(
        'en',
        'GB',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: LocalizationService.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LanguageSelectionScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // en_GB selects the English entry, which carries en_US.
      expect(
        tester
            .widget<RadioGroup<Locale>>(find.byType(RadioGroup<Locale>))
            .groupValue,
        SupportedLocale.en.locale,
      );

      container.read(localeStateProvider.notifier).locale = const Locale(
        'vi',
        'VN',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(SupportedLocale.en.displayName));
      await tester.pumpAndSettle();

      expect(container.read(localeStateProvider), const Locale('en', 'GB'));
    });
  });
}
