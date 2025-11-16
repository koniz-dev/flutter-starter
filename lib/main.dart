import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
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
class MyApp extends StatelessWidget {
  /// Creates a [MyApp] widget
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Starter',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Enable performance optimizations
      builder: (context, child) {
        // Wrap in RepaintBoundary for better performance
        return RepaintBoundary(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}

/// Home screen widget
class HomeScreen extends ConsumerWidget {
  /// Creates a [HomeScreen] widget
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Starter'),
        actions: [
          // Show debug menu button if debug features are enabled
          if (AppConfig.enableDebugFeatures)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FeatureFlagsDebugScreen(),
                  ),
                );
              },
              tooltip: 'Feature Flags Debug',
            ),
        ],
      ),
      body: const RepaintBoundary(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Welcome to Flutter Starter with Clean Architecture!'),
              SizedBox(height: 24),
              Text(
                'Feature Flags System is ready!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Check the examples in feature_flags_example_screen.dart',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
