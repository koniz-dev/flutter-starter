# Logging APIs

Comprehensive logging service for the application with multiple outputs and environment-aware formatting.

## Overview

The logging layer provides:
- `LoggingService` - Core logging management
- `LogOutput` templates - Plug-and-play outputs (Console, File, Crashlytics)
- `LogFormatter` - JSON and pretty-print formatting
- `LogProviders` - Riverpod providers for dependency injection

---

## LoggingService

Main service for handling all application logs.

**Location:** `lib/core/logging/logging_service.dart`

### Features

- **Multiple Levels**: debug, info, warning, error.
- **Structured Data**: Supports passing a `Map<String, dynamic>` as context.
- **Environment Aware**:
  - Dev: Pretty printing to console.
  - Prod: JSON formatting for easier ingestion by log aggregators.
- **Togglable**: Respects `ENABLE_LOGGING` flag from environment config.

### Usage

```dart
final logger = ref.read(loggingServiceProvider);

// Basic message
logger.info('User logged in');

// With context
logger.debug('Fetching data', context: {'id': 123, 'retry': true});

// With errors (automatically captures stack trace if not provided)
try {
  // ...
} catch (e, stack) {
  logger.error('Operation failed', error: e, stackTrace: stack);
}
```

---

## Crashlytics Template

An optional Firebase Crashlytics Log Output template.

**Location:** `lib/core/logging/crashlytics_output_template.dart`

### Setup

1. Run: `flutter pub add firebase_crashlytics`
2. Follow the instructions at the top of the file to uncomment the logic.
3. Add to `LoggingService`:
   ```dart
   if (_enableRemoteLogging) {
     outputs.add(CrashlyticsOutput());
   }
   ```

This template is opt-in and not enabled by default.

### Behavior

- Automatically filters logs to only send `Level.warning` and `Level.error` to Firebase.
- Maps `Level.error` as "fatal" errors in the Crashlytics dashboard.

---

## Related Documentation

- [Configuration System](../guides/configuration.md) - How to toggle logging via `.env`
- [Common Patterns](../examples/common-patterns.md) - Error handling and logging best practices
