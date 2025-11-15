import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  // This loads .env file if present, otherwise falls back to --dart-define
  // or defaults
  await EnvConfig.load();

  // Print configuration in debug mode (optional, useful for development)
  if (AppConfig.isDebugMode) {
    AppConfig.printConfig();
  }

  // Create ProviderContainer for initialization
  final container = ProviderContainer();

  // Initialize storage service via provider before app starts
  await container.read(storageInitializationProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

/// Root application widget
class MyApp extends StatelessWidget {
  /// Creates a [MyApp] widget
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Starter',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}

/// Home screen widget
class HomeScreen extends StatelessWidget {
  /// Creates a [HomeScreen] widget
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Starter'),
      ),
      body: const Center(
        child: Text('Welcome to Flutter Starter with Clean Architecture!'),
      ),
    );
  }
}
