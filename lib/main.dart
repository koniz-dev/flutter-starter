import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';

void main() async {
  // Ensure Flutter binding is initialized first (required for all Flutter APIs)
  WidgetsFlutterBinding.ensureInitialized();

  // Run initialization tasks in parallel where possible
  await Future.wait([
    // Load environment configuration
    EnvConfig.load(),
    // Initialize image cache settings for better performance
    _initializeImageCache(),
  ]);

  // Print configuration in debug mode (optional, useful for development)
  if (AppConfig.isDebugMode) {
    AppConfig.printConfig();
  }

  // Create ProviderContainer for initialization
  final container = ProviderContainer();

  // Initialize storage service via provider before app starts
  // This is done after env config to ensure storage is ready
  await container.read(storageInitializationProvider.future);

  // Initialize feature flags system
  // Note: Firebase Remote Config will be initialized here if Firebase is set
  // up. The system will gracefully fall back to local flags if Firebase is not
  // available
  await container.read(featureFlagsInitializationProvider.future);

  // Initialize locale from storage
  final localizationService = container.read(localizationServiceProvider);
  final savedLocale = await localizationService.getCurrentLocale();
  container.read(localeStateProvider.notifier).locale = savedLocale;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

/// Initialize image cache settings for optimal performance
Future<void> _initializeImageCache() async {
  // Set reasonable cache limits to balance memory usage and performance
  // These values can be adjusted based on app requirements
  imageCache.maximumSize = 100; // Maximum number of images
  imageCache.maximumSizeBytes = 100 << 20; // 100 MB
}

/// Root application widget
class MyApp extends ConsumerWidget {
  /// Creates a [MyApp] widget
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
      // Router configuration
      routerConfig: router,
      // Localization configuration
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      // RTL support
      builder: (context, child) {
        return Directionality(
          textDirection: textDirection,
          child: RepaintBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
