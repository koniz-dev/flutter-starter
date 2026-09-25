import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/startup/startup_failure_app.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression suite for koniz-dev/flutter-starter#101.
///
/// The bug was NOT that `StartupFailureApp` failed to paint - #60 already
/// proved that, by pumping the widget directly in
/// `test/acceptance/startup_failure_acceptance_test.dart`. The bug was that
/// nothing could ever *reach* it: `main()` built a bare `ProviderContainer()`,
/// Riverpod 3 retried the failed `storageInitializationProvider` because
/// `MigrationExecutionException implements Exception` rather than `Error`, and
/// with `container.read(p.future)` awaiting without listening the scheduled
/// retry invalidated a provider nobody watched. The future never completed,
/// `runApp` was never called, and the user got a black window.
///
/// So every test here drives reachability, not rendering:
/// * the provider is read through `app.createStartupContainer()`, the very
///   function `main()` calls, so a regression in main.dart's container fails
///   these tests rather than being papered over by a hand-rolled container;
/// * the end-to-end group calls the real `app.main()` and asserts on what it
///   passed to `runApp`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Installs an in-memory Keychain for the secure store.
  ///
  /// Without it every secure write is swallowed into `false`, the version
  /// stamp never persists, and `MigrationExecutor` reports the mismatch - one
  /// of the real failure paths #60 introduced.
  void installSecureBackend(Map<String, String> backing) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (methodCall) async {
          final arguments = methodCall.arguments as Map<Object?, Object?>?;
          final key = arguments?['key'] as String? ?? '';
          switch (methodCall.method) {
            case 'read':
              return backing[key];
            case 'write':
              backing[key] = arguments?['value'] as String? ?? '';
              return null;
            case 'delete':
              backing.remove(key);
              return null;
            case 'deleteAll':
              backing.clear();
              return null;
            default:
              return null;
          }
        });
  }

  void removeSecureBackend() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  }

  /// Serves a `.env` over the asset channel.
  ///
  /// `main()` starts with `EnvConfig.load()`, and the host test bundle has no
  /// `.env`. `EnvConfig` swallows the resulting `FlutterError`, but the failed
  /// future is cached by `CachingAssetBundle` and resurfaces as a late
  /// "uncaught exception after the test completed", failing tests that had
  /// already asserted correctly. Serving the asset removes the noise instead of
  /// teaching anyone to ignore it.
  void installEnvAsset() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != '.env') return null;
          final bytes = Uint8List.fromList(utf8.encode('ENVIRONMENT=test\n'));
          return ByteData.view(bytes.buffer);
        });
  }

  void removeEnvAsset() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  }

  setUp(() {
    // MANDATORY, and not boilerplate. The startup path reads SharedPreferences;
    // with no mock values the platform channel is unimplemented and the test
    // hangs rather than fails - the same symptom as the bug under test, which
    // would make a red run unreadable.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    removeSecureBackend();
    installEnvAsset();
  });

  tearDown(() {
    removeSecureBackend();
    removeEnvAsset();
  });

  /// Runs the real entrypoint and pumps until it has finished booting.
  ///
  /// Deliberately NOT `await app.main()` on the fake clock. Inside
  /// `testWidgets` the clock is fake, so anything `main()` waits on only
  /// advances while frames are being pumped; awaiting it directly deadlocks
  /// the test for reasons that have nothing to do with the bug. Starting it
  /// inside [WidgetTester.runAsync] and pumping afterwards is also the shape
  /// `integration_test/app_e2e_test.dart` uses on a device.
  ///
  /// The frame budget is the point of this helper. `expect(booted, isTrue)`
  /// is the bounded-time assertion #101 is about: on the pre-fix `main.dart`
  /// the startup future never completes, so `main()` never returns, and this
  /// fails with a readable message instead of hanging the suite.
  ///
  /// Shared by both end-to-end groups on purpose. The failure group and the
  /// healthy group must boot through the *same* code path, or "healthy" and
  /// "failed" stop being comparable outcomes of one entrypoint.
  /// Refs koniz-dev/flutter-starter#160
  Future<void> bootRealMain(WidgetTester tester) async {
    var booted = false;
    Object? bootError;

    // `tester.runAsync` is mandatory here, and not interchangeable with
    // pumping. `main()` does real I/O - dotenv reads the asset bundle,
    // SharedPreferences and the Keychain go over platform channels - and
    // `testWidgets` runs on a fake clock that never delivers those replies.
    // Awaiting `main()` on the fake clock stalls for reasons that have
    // nothing to do with #101, which would make a red run unreadable.
    await tester.runAsync(() async {
      try {
        await app.main().timeout(_bootBudget);
        booted = true;
      } on TimeoutException {
        booted = false;
      } on Object catch (error) {
        bootError = error;
        booted = true;
      }
    });

    // THE assertion this whole file exists for. #101 is not "the failure
    // screen renders wrong", it is "main() never returns, so no screen is
    // reached at all". On the pre-fix entrypoint this fails here, in bounded
    // time, instead of hanging the suite.
    expect(
      booted,
      isTrue,
      reason:
          'main() did not return within ${_bootBudget.inSeconds}s. That is '
          'the #101 hang: the awaited startup future stays pending, runApp '
          'is never called, and no screen - failure or otherwise - exists',
    );
    expect(
      bootError,
      isNull,
      reason:
          'main() must absorb a startup failure into StartupFailureApp, not '
          'throw out of the entrypoint',
    );

    // One bounded settle, outside `runAsync`, on the tree `runApp` attached.
    // `runApp` schedules `attachRootWidget` on a timer, so the tree exists but
    // has not necessarily been laid out when `main()`'s future completes; this
    // is what turns it into something `find` can interrogate.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  }

  group('startup container surfaces failures instead of hanging (#101)', () {
    test(
      'a real migration failure reaches the awaiting caller within 5s',
      () async {
        // No secure backend: the version stamp cannot persist, so
        // MigrationExecutor throws MigrationExecutionException rather than
        // returning a success the next launch would contradict.
        final container = app.createStartupContainer();
        addTearDown(container.dispose);

        await expectLater(
          container
              .read(storageInitializationProvider.future)
              .timeout(const Duration(seconds: 5)),
          throwsA(isA<MigrationExecutionException>()),
          reason:
              'main() awaits exactly this future before runApp; if it does not '
              'complete, StartupFailureApp is unreachable',
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('a downgrade refusal reaches the awaiting caller within 5s', () async {
      // Data stamped newer than this build understands. #60 made this throw
      // StorageDowngradeException, and it is a second, independent route into
      // the same hang - the issue only names the stamp-write path.
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageVersion.versionKey: '${StorageVersion.current + 1}',
      });
      installSecureBackend(<String, String>{});

      final container = app.createStartupContainer();
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(storageInitializationProvider.future)
            .timeout(const Duration(seconds: 5)),
        throwsA(isA<StorageDowngradeException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('a plain Exception from storage init is not retried away', () async {
      // Criterion 1 in its barest form: an `Exception`, not an `Error`, which
      // is precisely the class `ProviderContainer.defaultRetry` keeps retrying.
      final container = app.createStartupContainer(
        overrides: [
          storageInitializationProvider.overrideWith(
            (ref) async => throw Exception(_boom),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(storageInitializationProvider.future)
            .timeout(const Duration(seconds: 5)),
        throwsA(
          isA<Exception>().having((e) => '$e', 'toString', contains(_boom)),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('a session restoration failure is not retried away', () async {
      // Criterion 2. The shipped `sessionRestorationProvider` swallows its own
      // failures (see `AuthNotifier.restoreSession`), so it can only error when
      // a consumer replaces it - but `main()` awaits it with the identical
      // non-listening `read(...future)`, and it sits OUTSIDE the storage guard
      // on today's main.dart. Whatever makes it throw, the startup container
      // has to let that surface rather than park it in an eternal loading
      // state, so the policy is asserted here rather than assumed.
      final container = app.createStartupContainer(
        overrides: [
          sessionRestorationProvider.overrideWith(
            (ref) async => throw Exception(_boom),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(sessionRestorationProvider.future)
            .timeout(const Duration(seconds: 5)),
        throwsA(
          isA<Exception>().having((e) => '$e', 'toString', contains(_boom)),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('a healthy startup still completes normally', () async {
      // The negative control for the retry opt-out: turning retry off must not
      // turn success into failure, and must not be the reason the assertions
      // above go red. With a working secure store the same provider, read from
      // the same container `main()` builds, resolves.
      installSecureBackend(<String, String>{});

      final container = app.createStartupContainer();
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(storageInitializationProvider.future)
            .timeout(const Duration(seconds: 5)),
        completes,
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('the default container still hangs - the opt-out is load-bearing', () {
      // The control. This is what `main()` used to build, and it documents the
      // exact behaviour the fix removes: nothing throws, nothing resolves.
      //
      // If Riverpod ever changes `defaultRetry` so that this future completes,
      // this test fails and tells us the workaround in main.dart is no longer
      // the reason startup is safe. Deliberately *not* awaited into a pass:
      // `expectLater(..., completes)` cannot express "never finishes".
      final container = ProviderContainer();
      addTearDown(container.dispose);

      return expectLater(
        container
            .read(storageInitializationProvider.future)
            .timeout(const Duration(seconds: 3)),
        throwsA(isA<TimeoutException>()),
        reason:
            'a bare ProviderContainer retries the Exception forever with no '
            'listener to rebuild it, so the future stays pending',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('main() renders StartupFailureApp end to end (#101)', () {
    testWidgets('a failed version stamp boots into the failure screen', (
      tester,
    ) async {
      // No secure backend -> MigrationExecutionException out of migrateAll().
      await bootRealMain(tester);

      expect(
        find.byKey(StartupFailureApp.bodyKey),
        findsOneWidget,
        reason:
            'main() must have caught the migration failure and called runApp '
            'with StartupFailureApp',
      );
      // Ahem renders every glyph as a block, so these are find.text lookups
      // rather than anything read off a screenshot.
      expect(find.text("Couldn't start the app"), findsOneWidget);
      expect(find.byKey(StartupFailureApp.retryKey), findsOneWidget);
      expect(
        find.textContaining('MigrationExecutionException'),
        findsOneWidget,
        reason: 'the real exception is surfaced to the user, not a placeholder',
      );
    });

    testWidgets('a downgrade refusal boots into the failure screen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageVersion.versionKey: '${StorageVersion.current + 1}',
      });
      installSecureBackend(<String, String>{});

      await bootRealMain(tester);

      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(
        find.textContaining('StorageDowngradeException'),
        findsOneWidget,
        reason:
            'the second failure route reaches the same screen and names its '
            'own class, so main() is not rendering one canned error',
      );
    });
  });

  // The mirror image of the group above, and the whole point of #160.
  //
  // Both cases above *expect* `StartupFailureApp`, so a regression that turns
  // every launch into the failure screen makes them pass harder. #160 proved
  // that by mutation: injecting a throw into `main()`'s `try` left the entire
  // suite green at 2645 passing tests, and making
  // `LocalizationService.getCurrentLocale()` throw a `StateError` failed only
  // that service's own unit tests. Nothing asserted what a *healthy* boot
  // hands to `runApp`, which is exactly the shape of the closed #60 defect
  // inverted.
  //
  // An earlier comment here claimed this case could not be written, because
  // `runApp` runs inside `tester.runAsync` and building the full MyApp tree
  // from a warm-up frame there never returns. That is not what happens on the
  // pinned toolchain: `AutomatedTestWidgetsFlutterBinding.scheduleWarmUpFrame`
  // does a synchronous begin/draw pair *before* `attachRootWidget` has run off
  // its `Timer.run`, so the warm-up frame never touches the MyApp tree at all.
  // `main()` returns, and a single bounded `pumpAndSettle` afterwards settles
  // the whole app - router, Riverpod scope and localization included - in one
  // frame. The comment is replaced by the test it said was impossible.
  group('main() boots MyApp end to end on a healthy startup (#160)', () {
    testWidgets('a healthy startup hands MyApp to runApp, not the failure '
        'screen', (tester) async {
      // A working Keychain is what separates this from the first failure case:
      // the version stamp persists, `MigrationExecutor` agrees with itself,
      // and the whole widened `try` in `main()` runs to completion.
      installSecureBackend(<String, String>{});

      await bootRealMain(tester);

      // Criterion 1a: what `main()` handed to `runApp`. Read off the attached
      // tree rather than a hand-constructed one - `test/main_test.dart` and
      // `test/widget_test.dart` build `UncontrolledProviderScope(child: MyApp())`
      // themselves, which proves nothing about the entrypoint. The root widget
      // here is the one `main()`'s last line passed to `runApp`.
      //
      // Checked in two steps so the regression reads as a sentence rather
      // than as `Bad state: No element` out of `Iterable.single`: under the
      // mutation that makes every boot fail there is no scope in the tree at
      // all, and that is the finding worth printing.
      final scopeFinder = find.byType(UncontrolledProviderScope);
      expect(
        scopeFinder,
        findsOneWidget,
        reason:
            'main() reached runApp with something other than the '
            'UncontrolledProviderScope it builds on the healthy path - most '
            'likely StartupFailureApp, which carries no Riverpod scope',
      );
      final rootScope = tester.widget<UncontrolledProviderScope>(scopeFinder);
      expect(
        rootScope.child,
        isA<app.MyApp>(),
        reason:
            'main() must reach its final '
            'runApp(UncontrolledProviderScope(child: MyApp())) on a healthy '
            'boot; anything else means the '
            'on-Object catch branch swallowed a working startup',
      );

      // Criterion 1b: the failure screen is absent. Asserted three ways
      // because each catches a different regression - the key covers a
      // reachable StartupFailureApp, the type covers one rendered without its
      // body, and the string covers a copy-only stand-in. Text, not a golden:
      // goldens render every glyph as an opaque Ahem block.
      expect(
        find.byKey(StartupFailureApp.bodyKey),
        findsNothing,
        reason:
            'a healthy boot must not render the startup failure screen; if '
            'this finds a widget, main() took its catch branch on a launch '
            'that had nothing wrong with it',
      );
      expect(find.byType(StartupFailureApp), findsNothing);
      expect(find.text("Couldn't start the app"), findsNothing);

      // The tree really built, rather than merely being attached: only MyApp
      // uses `MaterialApp.router`, StartupFailureApp uses `MaterialApp(home:)`
      // with no router at all, so a non-null routerConfig discriminates the
      // two even if the finders above were somehow satisfied by an empty tree.
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        materialApp.routerConfig,
        isNotNull,
        reason:
            'StartupFailureApp has no routerConfig, so this is MyApp and its '
            'router resolved a route',
      );

      // The locale read is the last statement inside `main()`'s widened
      // `try`, after storage init and session restoration. A non-null locale
      // on the rendered MaterialApp is the observable end of that sequence:
      // if `getCurrentLocale()` throws, control never gets here at all.
      expect(materialApp.locale, isNotNull);
    });
  });
}

/// How long `main()` gets to finish booting before a test calls it hung.
///
/// Real seconds, not pumped ones: the point of #101 is that a startup
/// failure has to become visible in bounded time. The fixed entrypoint
/// finishes in tens of milliseconds; the broken one never finishes at all.
const Duration _bootBudget = Duration(seconds: 20);

const String _boom = 'startup blew up';

const MethodChannel _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Channel `rootBundle` uses to fetch assets under the test binding.
const String _assetChannel = 'flutter/assets';
