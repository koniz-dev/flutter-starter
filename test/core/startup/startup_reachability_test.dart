import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/logging/error_reporter_providers.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/startup/startup_failure_app.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression suite: a startup failure must reach the screen.
///
/// The bug was NOT that `StartupFailureApp` failed to paint - that was already
/// proved by pumping the widget directly in
/// `test/acceptance/startup_failure_acceptance_test.dart`. The bug was that
/// nothing could ever *reach* it: `main()` built a bare `ProviderContainer()`,
/// Riverpod 3 retried the failed `storageInitializationProvider` because
/// `MigrationExecutionException implements Exception` rather than `Error`, and
/// with `container.read(p.future)` awaiting without listening the scheduled
/// retry invalidated a provider nobody watched. The future never completed,
/// `runApp` was never called, and the user got a black window.
///
/// So every test here drives reachability, not rendering:
/// * the provider is read through `app.createAppContainer()`, the very
///   function `main()` calls, so a regression in main.dart's container fails
///   these tests rather than being papered over by a hand-rolled container;
/// * the end-to-end group calls the real `app.main()` and asserts on what it
///   passed to `runApp`.
class _RecordingReporter implements IErrorReporter {
  final reports = <({String message, Object? error, StackTrace? stack})>[];

  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    reports.add((message: message, error: error, stack: stackTrace));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Installs an in-memory Keychain for the secure store.
  ///
  /// Without it every secure write is swallowed into `false`, the version
  /// stamp never persists, and `MigrationExecutor` reports the mismatch - one
  /// of the real startup failure paths.
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
  ///
  /// [contents] defaults to a *known* environment: `main()` refuses
  /// to boot on an unknown one, so the healthy-path tests must not serve one.
  /// The asset is evicted first because `rootBundle` caches it by key, which
  /// would otherwise hand every later test the first test's `.env`.
  void installEnvAsset([String contents = 'ENVIRONMENT=development\n']) {
    rootBundle.evict('.env');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != '.env') return null;
          final bytes = Uint8List.fromList(utf8.encode(contents));
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
  /// is the bounded-time assertion this file is about: on the pre-fix
  /// `main.dart` the startup future never completes, so `main()` never
  /// returns, and this fails with a readable message instead of hanging the
  /// suite.
  ///
  /// Shared by both end-to-end groups on purpose. The failure group and the
  /// healthy group must boot through the *same* code path, or "healthy" and
  /// "failed" stop being comparable outcomes of one entrypoint.
  Future<void> bootRealMain(
    WidgetTester tester, {
    Future<void> Function() entry = app.main,
  }) async {
    var booted = false;
    Object? bootError;

    // `tester.runAsync` is mandatory here, and not interchangeable with
    // pumping. `main()` does real I/O - dotenv reads the asset bundle,
    // SharedPreferences and the Keychain go over platform channels - and
    // `testWidgets` runs on a fake clock that never delivers those replies.
    // Awaiting `main()` on the fake clock stalls for reasons that have
    // nothing to do with the hang, which would make a red run unreadable.
    await tester.runAsync(() async {
      try {
        await entry().timeout(_bootBudget);
        booted = true;
      } on TimeoutException {
        booted = false;
      } on Object catch (error) {
        bootError = error;
        booted = true;
      }
    });

    // THE assertion this whole file exists for. The bug is not "the failure
    // screen renders wrong", it is "main() never returns, so no screen is
    // reached at all". On the pre-fix entrypoint this fails here, in bounded
    // time, instead of hanging the suite.
    expect(
      booted,
      isTrue,
      reason:
          'main() did not return within ${_bootBudget.inSeconds}s. That is '
          'the startup hang: the awaited startup future stays pending, runApp '
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

  group('startup container surfaces failures instead of hanging', () {
    test(
      'a real migration failure reaches the awaiting caller within 5s',
      () async {
        // No secure backend: the version stamp cannot persist, so
        // MigrationExecutor throws MigrationExecutionException rather than
        // returning a success the next launch would contradict.
        final container = app.createAppContainer();
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
      // Data stamped newer than this build understands. This throws
      // StorageDowngradeException, and it is a second, independent route into
      // the same hang besides the stamp-write path.
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageVersion.versionKey: '${StorageVersion.current + 1}',
      });
      installSecureBackend(<String, String>{});

      final container = app.createAppContainer();
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
      final container = app.createAppContainer(
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
      final container = app.createAppContainer(
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

      final container = app.createAppContainer();
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

  group('main() renders StartupFailureApp end to end', () {
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

    testWidgets('the caught startup failure is reported once, with its '
        'stack', (tester) async {
      // No secure backend -> MigrationExecutionException, caught by main().
      final reporter = _RecordingReporter();
      await bootRealMain(
        tester,
        entry: () => app.bootstrap(
          createContainer: () => app.createAppContainer(
            overrides: [errorReporterProvider.overrideWithValue(reporter)],
          ),
        ),
      );

      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      // The migration also logs (and so reports) its own errors where they
      // happen; main() adds exactly one report saying the launch failed.
      final startup = reporter.reports.where(
        (r) => r.message == 'Startup failed',
      );
      expect(startup, hasLength(1));
      final report = startup.single;
      expect(report.error, isA<MigrationExecutionException>());
      expect(report.stack, isNotNull);
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

  // The mirror image of the group above.
  //
  // Both cases above *expect* `StartupFailureApp`, so a regression that turns
  // every launch into the failure screen makes them pass harder. A mutation
  // test proved that: injecting a throw into `main()`'s `try` left the entire
  // suite green at 2645 passing tests, and making
  // `LocalizationService.getCurrentLocale()` throw a `StateError` failed only
  // that service's own unit tests. Nothing asserted what a *healthy* boot
  // hands to `runApp`, which is exactly the shape of the original
  // startup defect inverted.
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
  // A release build with a mistyped
  // ENVIRONMENT used to boot against the development fallbacks - localhost,
  // no SSL pinning - with the only warning printed in debug builds.
  group('main() refuses an unknown ENVIRONMENT', () {
    testWidgets('ENVIRONMENT=prod boots into the failure screen, naming the '
        'value and the known environments', (tester) async {
      installSecureBackend(<String, String>{});
      installEnvAsset('ENVIRONMENT=prod\n');

      await bootRealMain(tester);

      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(find.textContaining('"prod"'), findsOneWidget);
      expect(
        find.textContaining('development, staging, production'),
        findsOneWidget,
      );
    });
  });

  // `development` is the default and what `.env.example` ships, so a release
  // built from an unedited `.env` was a development build in a release
  // binary: debug routes registered, pinning ignored, without a word.
  group('main() refuses a release build configured as development', () {
    testWidgets('a release build with ENVIRONMENT=development boots into the '
        'failure screen', (tester) async {
      installSecureBackend(<String, String>{});

      await bootRealMain(
        tester,
        entry: () => app.bootstrap(releaseMode: true),
      );

      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(find.textContaining('ENVIRONMENT=development'), findsOneWidget);
    });

    testWidgets('a release build with ENVIRONMENT=production starts', (
      tester,
    ) async {
      installSecureBackend(<String, String>{});
      installEnvAsset(
        'ENVIRONMENT=production\nAPI_SSL_FINGERPRINTS=${'a' * 64}\n',
      );

      await bootRealMain(
        tester,
        entry: () => app.bootstrap(releaseMode: true),
      );

      expect(find.byKey(StartupFailureApp.bodyKey), findsNothing);
      expect(find.byType(app.MyApp), findsOneWidget);
    });

    testWidgets('a release build with pinning on and no fingerprints boots '
        'into the failure screen', (tester) async {
      installSecureBackend(<String, String>{});
      installEnvAsset('ENVIRONMENT=production\n');

      await bootRealMain(
        tester,
        entry: () => app.bootstrap(releaseMode: true),
      );

      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(find.textContaining('API_SSL_FINGERPRINTS'), findsOneWidget);
    });

    testWidgets('a release build with an unrecognised ENABLE_SSL_PINNING '
        'boots into the failure screen, naming the value', (tester) async {
      installSecureBackend(<String, String>{});
      installEnvAsset(
        'ENVIRONMENT=production\nAPI_SSL_FINGERPRINTS=${'a' * 64}\n'
        'ENABLE_SSL_PINNING=enabled\n',
      );

      await bootRealMain(
        tester,
        entry: () => app.bootstrap(releaseMode: true),
      );

      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(find.textContaining('"enabled"'), findsOneWidget);
    });

    testWidgets('a release build that opts out of pinning starts without '
        'fingerprints', (tester) async {
      installSecureBackend(<String, String>{});
      installEnvAsset('ENVIRONMENT=production\nENABLE_SSL_PINNING=false\n');

      await bootRealMain(
        tester,
        entry: () => app.bootstrap(releaseMode: true),
      );

      expect(find.byKey(StartupFailureApp.bodyKey), findsNothing);
      expect(find.byType(app.MyApp), findsOneWidget);
    });

    testWidgets('a non-release development build starts', (tester) async {
      installSecureBackend(<String, String>{});

      await bootRealMain(tester);

      expect(find.byKey(StartupFailureApp.bodyKey), findsNothing);
    });
  });

  // main() installs the uncaught-error handlers, and they live as long as the
  // container whose LoggingService they log through: removed with a failed
  // container, installed again - once - by Try again.
  group('main() and the uncaught-error handlers', () {
    late void Function(FlutterErrorDetails)? flutterBefore;
    late ErrorCallback? platformBefore;

    // Read inside the test body: testWidgets installs its own
    // FlutterError.onError after setUp has run.
    void recordHandlers() {
      app.debugForgetUncaughtErrorHandlers();
      flutterBefore = FlutterError.onError;
      platformBefore = PlatformDispatcher.instance.onError;
      addTearDown(() {
        app.debugForgetUncaughtErrorHandlers();
        FlutterError.onError = flutterBefore;
        PlatformDispatcher.instance.onError = platformBefore;
      });
    }

    Future<void> Function() bootWith(_RecordingReporter reporter) =>
        () => app.bootstrap(
          createContainer: () => app.createAppContainer(
            overrides: [errorReporterProvider.overrideWithValue(reporter)],
          ),
        );

    testWidgets('a healthy startup installs both handlers', (tester) async {
      recordHandlers();
      installSecureBackend(<String, String>{});

      await bootRealMain(tester, entry: bootWith(_RecordingReporter()));

      expect(FlutterError.onError, isNot(same(flutterBefore)));
      expect(PlatformDispatcher.instance.onError, isNot(same(platformBefore)));
    });

    testWidgets('Try again after a startup failure installs them once, so an '
        'uncaught error is reported once', (tester) async {
      recordHandlers();
      final reporter = _RecordingReporter();

      // No secure backend: the first launch fails.
      await bootRealMain(tester, entry: bootWith(reporter));
      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(
        FlutterError.onError,
        same(flutterBefore),
        reason: 'the handlers go with the failed, disposed container',
      );

      // Fix the cause and press Try again: run the screen's own onRetry.
      installSecureBackend(<String, String>{});
      final failure = tester.widget<StartupFailureApp>(
        find.byType(StartupFailureApp),
      );
      await bootRealMain(tester, entry: failure.onRetry!);
      expect(find.byKey(StartupFailureApp.bodyKey), findsNothing);
      expect(FlutterError.onError, isNot(same(flutterBefore)));

      reporter.reports.clear();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('after retry'),
          stack: StackTrace.current,
        ),
      );
      // The test binding's handler, chained behind ours, recorded it too.
      expect(tester.takeException(), isA<StateError>());
      await tester.pump();

      expect(
        reporter.reports.where((r) => r.message == 'Uncaught Flutter error'),
        hasLength(1),
      );
    });
  });

  group('main() boots MyApp end to end on a healthy startup', () {
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
/// Real seconds, not pumped ones: the point of this suite is that a startup
/// failure has to become visible in bounded time. The fixed entrypoint
/// finishes in tens of milliseconds; the broken one never finishes at all.
const Duration _bootBudget = Duration(seconds: 20);

const String _boom = 'startup blew up';

const MethodChannel _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Channel `rootBundle` uses to fetch assets under the test binding.
const String _assetChannel = 'flutter/assets';
