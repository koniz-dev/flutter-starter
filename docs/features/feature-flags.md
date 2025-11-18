# Feature Flags System

A comprehensive feature flags system for enabling/disabling features dynamically in your Flutter app.

## Overview

The feature flags system provides:

- **Local Feature Flags**: Compile-time, environment-based, and debug/release flags
- **Remote Feature Flags**: Firebase Remote Config integration with real-time updates
- **Type-Safe Access**: Centralized flag definitions with compile-time safety
- **Debug Tools**: UI for managing flags during development
- **Analytics Support**: Track flag usage and A/B testing

## Architecture

The feature flags system follows Clean Architecture principles:

```
┌─────────────────────────────────────┐
│   Presentation Layer                │
│   - Debug Screen, Widgets           │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Domain Layer                      │
│   - FeatureFlag Entity              │
│   - FeatureFlagsRepository          │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Data Layer                        │
│   - LocalFeatureFlagsService        │
│   - RemoteDataSource (Firebase)     │
│   - LocalDataSource (Storage)       │
│   - Repository Implementation       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Core Layer                        │
│   - FeatureFlagsManager             │
│   - FeatureFlagKey Definitions      │
└─────────────────────────────────────┘
```

## Priority Order

Feature flags are resolved in the following priority order (highest to lowest):

1. **Local Override** - Set via debug menu or programmatically
2. **Remote Config** - Firebase Remote Config values
3. **Environment** - `.env` file or `--dart-define` flags
4. **Build Mode** - Debug vs Release mode defaults
5. **Compile-Time** - Hardcoded default values

## Usage

### 1. Defining Feature Flags

All feature flags should be defined in `lib/core/feature_flags/feature_flags_manager.dart`:

```dart
class FeatureFlags {
  FeatureFlags._();

  static const FeatureFlagKey newFeature = FeatureFlagKey(
    value: 'enable_new_feature',
    defaultValue: false,
    description: 'Enable the new experimental feature',
    category: 'Features',
  );
}
```

### 2. Using FeatureFlagBuilder

Use `FeatureFlagBuilder` for conditional rendering:

```dart
FeatureFlagBuilder(
  flag: FeatureFlags.newFeature,
  enabledBuilder: (context) => NewFeatureWidget(),
  disabledBuilder: (context) => OldFeatureWidget(),
)
```

### 3. Using FeatureFlagWidget

For simple show/hide scenarios:

```dart
FeatureFlagWidget(
  flag: FeatureFlags.newFeature,
  child: NewFeatureWidget(),
  fallback: OldFeatureWidget(), // Optional
)
```

### 4. Direct Provider Access

For complex logic, access flags directly:

```dart
final isEnabled = ref.watch(
  isFeatureEnabledProvider(FeatureFlags.newFeature),
);

isEnabled.when(
  data: (enabled) {
    if (enabled) {
      // Show new feature
    }
  },
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
);
```

### 5. Programmatic Access

Use `FeatureFlagsManager` for programmatic access:

```dart
final manager = ref.read(featureFlagsManagerProvider);
final isEnabled = await manager.isEnabled(FeatureFlags.newFeature);
```

## Local Feature Flags

### Compile-Time Flags

Define flags with compile-time defaults:

```dart
static const FeatureFlagKey myFlag = FeatureFlagKey(
  value: 'my_flag',
  defaultValue: false, // Compile-time default
  description: 'My feature flag',
);
```

### Environment-Based Flags

Set flags via environment variables:

```bash
# In .env file
FEATURE_ENABLE_NEW_FEATURE=true
```

Or via `--dart-define`:

```bash
flutter run --dart-define=FEATURE_ENABLE_NEW_FEATURE=true
```

### Debug vs Release Flags

Flags can have different defaults for debug and release builds:

```dart
// In LocalFeatureFlagsService
LocalFlagDefinition(
  key: 'enable_debug_menu',
  compileTimeDefault: false,
  debugDefault: true,      // Enabled in debug
  releaseDefault: false,   // Disabled in release
  description: 'Enable debug menu',
),
```

## Remote Feature Flags (Firebase Remote Config)

### Setup

1. **Add Firebase to your project** (if not already done):
   - Follow [Firebase setup guide](https://firebase.google.com/docs/flutter/setup)
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

2. **Initialize Firebase** in `main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // ... rest of initialization
}
```

3. **Configure Remote Config** in Firebase Console:
   - Go to Firebase Console > Remote Config
   - Add your feature flags as boolean parameters
   - Set default values

### Default Values

Set default values for remote config in `feature_flags_remote_datasource_provider`:

```dart
final defaultValues = <String, dynamic>{
  'enable_new_feature': false,
  'enable_premium_features': false,
  // ... other flags
};
```

### Fetching Remote Flags

Remote flags are automatically fetched during app initialization. To manually refresh:

```dart
await ref.read(featureFlagsManagerProvider).refresh();
```

### Real-Time Updates

Remote Config supports real-time updates. The system will fetch new values when:
- App starts
- `refresh()` is called
- Based on the minimum fetch interval (default: 1 hour)

## Debug Menu

The debug menu allows developers to:
- View all feature flags and their current values
- See the source of each flag (local override, remote, environment, etc.)
- Toggle flags for testing
- Clear local overrides

### Accessing Debug Menu

1. **Via App Bar** (if `AppConfig.enableDebugFeatures` is true):
   - Tap the bug icon in the app bar

2. **Programmatically**:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const FeatureFlagsDebugScreen(),
  ),
);
```

### Features

- **Toggle Flags**: Tap the switch to enable/disable a flag
- **Clear Override**: Long press a flag to clear its local override
- **Refresh**: Tap refresh icon to fetch latest remote flags
- **Clear All**: Tap clear icon to remove all local overrides

## A/B Testing Support

Feature flags can be used for A/B testing:

1. **Define Variants**:
```dart
static const FeatureFlagKey abTestVariant = FeatureFlagKey(
  value: 'ab_test_variant',
  defaultValue: false,
  description: 'A/B test variant',
);
```

2. **Configure in Firebase**:
   - Set up user targeting in Firebase Remote Config
   - Define percentage rollouts
   - Use user properties for targeting

3. **Track Usage**:
```dart
if (await manager.isEnabled(FeatureFlags.abTestVariant)) {
  // Track variant A
  analytics.logEvent('ab_test_variant_a');
} else {
  // Track variant B
  analytics.logEvent('ab_test_variant_b');
}
```

## Analytics Integration

Track feature flag usage:

```dart
final flag = await manager.getFlag(FeatureFlags.newFeature);
analytics.logEvent('feature_flag_accessed', parameters: {
  'flag_key': flag.key,
  'flag_value': flag.value,
  'flag_source': flag.source.name,
});
```

## Best Practices

1. **Centralize Definitions**: Always define flags in `FeatureFlags` class
2. **Use Type-Safe Keys**: Use `FeatureFlagKey` constants, not strings
3. **Document Flags**: Always provide descriptions
4. **Set Sensible Defaults**: Default to `false` for new features
5. **Test Both States**: Test your app with flags enabled and disabled
6. **Remove Dead Code**: Remove feature flag checks once a feature is fully rolled out
7. **Monitor Usage**: Track which flags are being used and their impact

## Examples

See `lib/features/feature_flags/presentation/examples/feature_flags_example_screen.dart` for complete examples.

## Troubleshooting

### Flags Not Updating

1. Check if local override exists (via debug menu)
2. Verify Firebase Remote Config is initialized
3. Check network connectivity for remote flags
4. Verify environment variables are set correctly

### Firebase Not Working

The system gracefully falls back to local flags if Firebase is not initialized. Check:
1. Firebase is properly initialized
2. `google-services.json` / `GoogleService-Info.plist` are present
3. Firebase Remote Config is enabled in Firebase Console

### Flags Not Found

If a flag is not found:
1. Verify it's defined in `FeatureFlags` class
2. Check the flag key matches exactly (case-sensitive)
3. Ensure default value is set

## API Reference

### FeatureFlagsManager

- `isEnabled(FeatureFlagKey key)`: Check if a flag is enabled
- `getFlag(FeatureFlagKey key)`: Get full flag details
- `getFlags(List<FeatureFlagKey> keys)`: Get multiple flags
- `refresh()`: Refresh remote flags
- `setLocalOverride(FeatureFlagKey key, bool value)`: Set local override
- `clearLocalOverride(FeatureFlagKey key)`: Clear local override
- `clearAllLocalOverrides()`: Clear all local overrides

### Providers

- `featureFlagsManagerProvider`: Main manager instance
- `isFeatureEnabledProvider(FeatureFlagKey)`: Check if flag is enabled
- `featureFlagProvider(FeatureFlagKey)`: Get flag details
- `allFeatureFlagsProvider`: Get all flags
- `featureFlagsInitializationProvider`: Initialize system

### Widgets

- `FeatureFlagBuilder`: Conditional rendering with builders
- `FeatureFlagWidget`: Simple show/hide widget
- `FeatureFlagsDebugScreen`: Debug menu screen

