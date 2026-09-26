// Stripped baseline: keep bootstrap minimal (docs live in repo docs).
// ignore_for_file: public_member_api_docs

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
// Refs koniz-dev/flutter-starter#101
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
  // the auth slice fills them (koniz-dev/flutter-starter#221).
  return ProviderContainer(
    retry: _neverRetry,
    overrides: <Override>[...authModuleOverrides, ...overrides],
  );
}

// Returns a Future so callers can await startup. `void main() async` would
// discard it: integration tests could not wait for runApp, and any error
// thrown by the awaits below would surface as an unhandled async error
// instead of propagating.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([EnvConfig.load(), _initializeImageCache()]);

  if (AppConfig.isDebugMode) {
    AppConfig.printConfig();
  }

  final container = createAppContainer();

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
  } on Object catch (error) {
    container.dispose();
    runApp(StartupFailureApp(error: error, onRetry: main));
    return;
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

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
