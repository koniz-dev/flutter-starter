import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/logging/noop_error_reporter.dart';

/// Provider for the [IErrorReporter] that `loggingServiceProvider` forwards
/// errors to. By default it reports nothing; override it once, where the app
/// container is built, to plug in Crashlytics, Sentry or your own service:
///
/// ```dart
/// errorReporterProvider.overrideWithValue(CrashlyticsErrorReporter()),
/// ```
final errorReporterProvider = Provider<IErrorReporter>((ref) {
  return const NoOpErrorReporter();
});
