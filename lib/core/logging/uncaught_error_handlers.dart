import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';

/// Routes errors nothing else caught to [logger], so the `IErrorReporter`
/// behind `LoggingService.error` sees crashes as well as handled errors.
///
/// - `FlutterError.onError` receives framework errors: a throwing `build`,
///   layout or paint, gesture callbacks.
/// - [PlatformDispatcher.onError] receives errors that escaped every zone,
///   such as an un-awaited `Future` that fails. The handler returns `true` so
///   the engine treats the error as handled instead of printing it again.
///
/// Both chain to the handler that was installed before, so framework errors
/// are still dumped to the console as usual.
///
/// Returns a callback that puts the previous handlers back. `main()` calls it
/// before installing again, because the startup failure screen's Try again
/// re-runs `main()` with a new container.
VoidCallback installUncaughtErrorHandlers(
  LoggingService logger, {
  PlatformDispatcher? dispatcher,
}) {
  final platform = dispatcher ?? PlatformDispatcher.instance;
  final previousFlutter = FlutterError.onError;
  final previousPlatform = platform.onError;

  FlutterError.onError = (details) {
    logger.error(
      'Uncaught Flutter error',
      error: details.exception,
      stackTrace: details.stack,
      context: {
        if (details.library != null) 'library': details.library,
        'silent': details.silent,
      },
    );
    previousFlutter?.call(details);
  };

  platform.onError = (error, stackTrace) {
    logger.error(
      'Uncaught platform error',
      error: error,
      stackTrace: stackTrace,
    );
    previousPlatform?.call(error, stackTrace);
    return true;
  };

  return () {
    FlutterError.onError = previousFlutter;
    platform.onError = previousPlatform;
  };
}
