# Logging APIs

Comprehensive logging service for the application with multiple outputs and environment-aware formatting.

## Overview

The logging layer provides:
- `LoggingService` - Core logging management
- `LogOutput` implementations - Console and file outputs (`lib/core/logging/log_output.dart`)
- `IErrorReporter` - The crash reporting seam `LoggingService.error` forwards to (see [Error reporting](#error-reporting))
- `JsonLogFormatter` - JSON log printer used outside development (`lib/core/logging/log_output.dart`)
- `loggingServiceProvider` - Riverpod provider for dependency injection (`lib/core/logging/logging_providers.dart`)

Worked examples - a use case, a repository and an API client logging with
context, and masking identifiers first - are in
[`examples/logging_examples.dart`](../../../examples/logging_examples.dart).
They are reference snippets, not app code.

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
- **Togglable**: `ENABLE_LOGGING=false` turns every output off. It defaults to `true` in every environment.
- **Levels per build**: production writes `info` and above; staging and development write `debug` and above. The level is the only filter, in every build mode - profile and release included. (The `logger` package's default filter drops everything once asserts are off, so `LoggingService` never uses it.)
- **Outputs**: the console in debug builds, `logs/app.log` in production, and the console as a fallback in any build that would otherwise have no output. The per-build table is in [Where logs go](../../guides/configuration.md#where-logs-go).

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

## Error reporting

`LoggingService.error` forwards every error it logs - the message, the error
object, its stack trace and the context map - to an `IErrorReporter`. Features
keep logging through `loggingServiceProvider` and never call a crash reporting
SDK themselves.

| Piece | Location |
| --- | --- |
| Interface | `IErrorReporter` in `lib/core/logging/i_error_reporter.dart` |
| Default | `NoOpErrorReporter` in `lib/core/logging/noop_error_reporter.dart` - reports nothing |
| Provider to override | `errorReporterProvider` in `lib/core/logging/error_reporter_providers.dart` |
| Crashlytics example | `CrashlyticsErrorReporter` in `lib/core/logging/crashlytics_error_reporter_template.dart` |

Two behaviours to know:

- **Reporting ignores `ENABLE_LOGGING`.** That toggle governs log outputs.
  Which reporter is bound governs reporting, so turning logs off does not
  silently drop crash reports.
- **A failing reporter never breaks the caller.** If `recordError` throws, or
  its future fails, `LoggingService` logs a warning (`Error reporter failed`)
  and carries on. The warning goes to the logger directly, not back to the
  reporter.

### What reaches the reporter

| Source | Reported? | How |
| --- | --- | --- |
| `LoggingService.error(...)` called by app code | Yes | Directly |
| Uncaught framework errors (a throwing `build`, layout, paint, gesture callback) | Yes | `FlutterError.onError`, installed by `installUncaughtErrorHandlers` in `main()` |
| Errors that escape every zone (an un-awaited `Future` that fails) | Yes | `PlatformDispatcher.onError`, same installer; it returns `true`, so the engine does not print the error again |
| `debug`, `info`, `warning` calls | No | Logged only |
| An error that code catches and does not pass to `error()` | No | Nothing sees it |
| A startup failure `main()` catches (storage migration, session restore, locale read, an unknown `ENVIRONMENT`) | Yes | `main()` calls `error('Startup failed', ...)` once before showing the failure screen. The step that failed may already have logged, and so reported, its own error (the migration does) |
| Anything thrown before `main()` builds the container (`EnvConfig.load`, binding setup) | No | The handlers are not installed yet |
| Errors while the startup failure screen is shown | No | The handlers are removed with the failed container; Try again installs them again |
| Native crashes (a crash in Kotlin, Swift or the engine) | No | Needs the vendor SDK's native integration |

`installUncaughtErrorHandlers` (`lib/core/logging/uncaught_error_handlers.dart`)
chains to the handlers that were set before it, so framework errors are still
dumped to the console as before. The red error screen comes from
`ErrorWidget.builder` and is not affected. Its return value restores them;
`main()` uses it so the startup failure screen's Try again, which re-runs
`main()`, does not install a second set.

### Plugging in Crashlytics

1. Run `flutter pub add firebase_crashlytics` and initialise Firebase.
2. In `lib/core/logging/crashlytics_error_reporter_template.dart`, uncomment
   the import and the body of `recordError`.
3. Override the provider once, where the app container is built:

   ```dart
   errorReporterProvider.overrideWithValue(CrashlyticsErrorReporter()),
   ```

### Plugging in Sentry or your own service

Implement the interface and override the same provider:

```dart
class SentryErrorReporter implements IErrorReporter {
  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) =>
      Sentry.captureException(error ?? message, stackTrace: stackTrace);
}
```

### Analytics, push notifications and other services

The starter ships no analytics or push seam, on purpose: nothing in it would
call one, and
[ADR 0006](../../architecture/adr/0006-contract-status-and-slice-shape.md)
rules out a contract with no production consumer. When your app gets its
first consumer, add the seam with the same three pieces, next to that consumer:

1. An interface (`IAnalyticsService` with `logEvent`, say).
2. A no-op default, so tests and builds without the vendor still run.
3. A `Provider` typed on the interface that returns the no-op, which you
   override with the vendor adapter where the app container is built.

Features then read the provider, never the SDK. `IErrorReporter` and
`IRaspService` (`lib/core/security/`) are the two worked examples in this
tree.

---

## Related Documentation

- [Configuration System](../../guides/configuration.md) - How to toggle logging via `.env`
- [Common Patterns](../examples/common-patterns.md) - Error handling and logging best practices
