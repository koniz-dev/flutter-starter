// Variant baseline: keep bootstrap minimal (docs live in repo docs).
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([EnvConfig.load(), _initializeImageCache()]);

  if (AppConfig.isDebugMode) {
    AppConfig.printConfig();
  }

  final container = ProviderContainer();

  await container.read(storageInitializationProvider.future);

  final localizationService = container.read(localizationServiceProvider);
  final savedLocale = await localizationService.getCurrentLocale();
  container.read(localeStateProvider.notifier).locale = savedLocale;

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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
