// Stripped baseline: keep bootstrap minimal (docs live in repo docs).
// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is not in flutter_riverpod.dart's export list; misc.dart is
// where riverpod 3 exposes it. Needed only for createAppContainer's
// test seam.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/uncaught_error_handlers.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/startup/startup_failure_app.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';

// Disables Riverpod auto-retry for EVERY provider, for the whole process
// lifetime - not just for startup. A container-level `Retry` is
// `(int, Object) -> Duration?`; it is never told which provider failed, so
// "off for startup, default elsewhere" is not expressible, and this container
// is the one handed to `runApp`. Per-provider `retry:` is the provider-aware
// lever: riverpod resolves `origin.retry ?? container.retry ?? defaultRetry`.
// docs/architecture/riverpod-retry-policy.md is the adopter-facing writeup.
//
// Why off at all: riverpod 3 retries any failed provider whose error is not an
// `Error` (`ProviderContainer.defaultRetry`), and every failure the startup
// sequence can produce here is an `Exception`: `MigrationExecutionException`,
// `StorageDowngradeException`, `MigrationPathException`, `CacheException`.
//
// That default is actively harmful on this path. `main()` reads providers with
// `container.read(p.future)`, which awaits without listening, so the retry
// timer invalidates a provider nobody is watching, it never rebuilds, and the
// awaited future stays in the loading state forever - measured past 120 s with
// the migration body having run exactly once. The `StartupFailureApp` guard
// below then never fires and the user gets a process that never calls
// `runApp`: a black window with no error, no retry, and no way out. A visible
// failure is recoverable, an unbounded hang is not, so startup opts out and
// lets the exception surface. Retry here stays user-driven, via the Try again
// button that calls `main()` again.
Duration? _neverRetry(int retryCount, Object error) => null;

/// Builds the app's one [ProviderContainer]: `main()` boots from it and then
/// hands the same instance to `runApp`, so the retry policy it sets applies
/// for the lifetime of the app and not only to the startup sequence.
///
/// Named for that lifetime rather than for the moment of construction: every
/// provider the app ever rebuilds is governed by the [_neverRetry] passed
/// here. See [_neverRetry] and `docs/architecture/riverpod-retry-policy.md`
/// for why retry is off and what to do about a provider that needs it.
///
/// `@visibleForTesting` marks the `overrides` seam, not the function: this is
/// the production factory. It exists so tests can drive the real startup
/// sequence through the same container the app uses, rather than a
/// hand-rolled one that happens to be configured differently.
@visibleForTesting
ProviderContainer createAppContainer({
  List<Override> overrides = const <Override>[],
}) {
  // `authModuleOverrides` first, so a caller-supplied override of the same
  // provider still wins: this is the composition root, and it is the only
  // place that knows both that core declares the 401-refresh seams and that
  // the auth slice fills them.
  return ProviderContainer(
    retry: _neverRetry,
    overrides: <Override>[...authModuleOverrides, ...overrides],
  );
}

// Returns a Future so callers can await startup. `void main() async` would
// discard it: integration tests could not wait for runApp, and any error
// thrown by the awaits below would surface as an unhandled async error
// instead of propagating.
Future<void> main() => bootstrap();

/// The body of [main], with the container factory as a seam: a test passes
/// one built by [createAppContainer] with overrides (a recording error
/// reporter, say) and drives the real startup sequence through it. The
/// startup failure screen's Try again re-runs it with the same factory.
///
/// [releaseMode] is `kReleaseMode` unless a test stands in for a release
/// build, which a test run can never be.
@visibleForTesting
Future<void> bootstrap({
  ProviderContainer Function() createContainer = createAppContainer,
  bool releaseMode = kReleaseMode,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([EnvConfig.load(), _initializeImageCache()]);

  if (AppConfig.isDebugMode) {
    AppConfig.printConfig();
  }

  final container = createContainer();

  // From here on, errors nothing else catches reach LoggingService and so the
  // bound IErrorReporter. A retry from the startup failure screen re-runs
  // main() with a new container: restore first, so handlers do not stack.
  _restoreErrorHandlers?.call();
  _restoreErrorHandlers = installUncaughtErrorHandlers(
    container.read(loggingServiceProvider),
  );

  // Everything before the first frame runs inside one guard. Throwing here
  // means `runApp` is never reached: a black window on every launch, with no
  // way out. Catching `Object` rather than `Exception` is deliberate - a
  // migration reading a key whose stored type changed throws a `TypeError`,
  // which is an `Error`.
  //
  // The guard covers the whole sequence, not just the migration: session
  // restoration and the locale read both touch the same storage the migration
  // just failed to prepare, and an unguarded throw from either is the same
  // black window by another route.
  try {
    // An ENVIRONMENT outside AppConfig.knownEnvironments (a typo like `prod`)
    // makes isDevelopment, isStaging and isProduction all false: the base URL
    // falls back to localhost and SSL pinning is off. printConfig() only warns
    // in debug, so a release build booted silently on that config. Refuse to
    // start instead, through the same failure screen as any other startup
    // error.
    if (AppConfig.environmentMisconfigured) {
      throw StateError(
        'ENVIRONMENT "${AppConfig.environment}" is not one of '
        '${AppConfig.knownEnvironments.join(', ')}. Refusing to start: the '
        'base URL would fall back to localhost and SSL pinning would be off.',
      );
    }
    if (AppConfig.releaseBuiltAsDevelopment(releaseMode: releaseMode)) {
      throw StateError(
        'This release build is configured as ENVIRONMENT=development, which '
        'registers the debug routes and turns HTTP logging on. Build it with '
        'ENVIRONMENT=staging or production.',
      );
    }
    if (releaseMode && AppConfig.sslPinningFlagUnrecognised) {
      final flag = _shown(EnvConfig.get('ENABLE_SSL_PINNING'));
      throw StateError(
        'ENABLE_SSL_PINNING is "$flag", '
        'which '
        'is neither on (${AppConfig.sslPinningOnValues.join('/')}) nor off '
        '(${AppConfig.sslPinningOffValues.join('/')}). Refusing to start '
        'rather than guess whether this release should be pinned.',
      );
    }
    if (AppConfig.releasePinningMisconfigured(releaseMode: releaseMode)) {
      throw StateError(
        'SSL pinning is on for this release build, but API_SSL_FINGERPRINTS '
        'is empty, so nothing would be pinned. Build it with '
        'API_SSL_FINGERPRINTS set, or with ENABLE_SSL_PINNING=false to opt '
        'out of pinning explicitly.',
      );
    }

    // Storage initialization runs the schema migrations. It is the one startup
    // step that can fail with the user's local data on the line.
    await container.read(storageInitializationProvider.future);

    // Restore a session persisted by a previous launch BEFORE the first frame.
    // Without this the app boots unauthenticated, the router redirects to
    // /login, and every cold start logs the user out even though the user and
    // tokens are still on disk. Awaiting here also means the router never sees
    // the restore-in-flight state in production.
    await container.read(sessionRestorationProvider.future);

    final localizationService = container.read(localizationServiceProvider);
    final savedLocale = await localizationService.getCurrentLocale();
    container.read(localeStateProvider.notifier).locale = savedLocale;
  } on Object catch (error, stackTrace) {
    // Caught here, so neither uncaught-error handler sees it: report it
    // explicitly, or a failed launch never reaches the bound IErrorReporter.
    try {
      container
          .read(loggingServiceProvider)
          .error('Startup failed', error: error, stackTrace: stackTrace);
    } on Object {
      // Reporting must not stand between the user and the failure screen.
    }
    // The handlers log through this container's LoggingService, which is
    // about to be disposed: take them down with it. Try again installs them
    // afresh with the next container.
    _restoreErrorHandlers?.call();
    _restoreErrorHandlers = null;
    container.dispose();
    runApp(
      StartupFailureApp(
        error: error,
        onRetry: () => bootstrap(
          createContainer: createContainer,
          releaseMode: releaseMode,
        ),
      ),
    );
    return;
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

VoidCallback? _restoreErrorHandlers;

/// Forgets the handlers a previous [bootstrap] installed, without restoring
/// what they replaced. A test that boots the app more than once in one
/// isolate calls this first, so a restore callback left by an earlier test
/// does not reinstate that test's handlers.
@visibleForTesting
void debugForgetUncaughtErrorHandlers() => _restoreErrorHandlers = null;

Future<void> _initializeImageCache() async {
  imageCache.maximumSize = 100;
  imageCache.maximumSizeBytes = 100 << 20;
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch<Locale>(localeStateProvider);
    final textDirection = ref.watch<TextDirection>(textDirectionProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Flutter Starter',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      builder: (context, child) {
        return Directionality(
          textDirection: textDirection,
          child: RepaintBoundary(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// [value] cut to 32 characters, for a refusal shown on screen and in the
/// logs: it is a config value, but one someone may have pasted a secret into.
String _shown(String value) =>
    value.length <= 32 ? value : '${value.substring(0, 32)}...';
