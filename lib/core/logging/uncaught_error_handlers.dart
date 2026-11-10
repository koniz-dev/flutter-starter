import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';

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
/// are still dumped to the console with the same credential redaction.
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
    final safeError = _redactError(details.exception);
    logger.error(
      'Uncaught Flutter error',
      error: safeError,
      stackTrace: details.stack,
      context: {
        if (details.library != null) 'library': details.library,
        'silent': details.silent,
      },
    );
    final originalCollector = details.informationCollector;
    final safeContext = details.context == null
        ? null
        : _redactDiagnostic(details.context!);
    previousFlutter?.call(
      identical(safeError, details.exception) &&
              identical(safeContext, details.context) &&
              originalCollector == null
          ? details
          : details.copyWith(
              exception: safeError,
              context: safeContext,
              // Keep collection lazy, and do not forward credential-bearing
              // objects such as NetworkImage as diagnostic property values.
              informationCollector: originalCollector == null
                  ? null
                  : () => originalCollector().map(
                      (node) =>
                          ErrorDescription(_redactText(_diagnosticText(node))),
                    ),
            ),
    );
  };

  platform.onError = (error, stackTrace) {
    final safeError = _redactError(error);
    logger.error(
      'Uncaught platform error',
      error: safeError,
      stackTrace: stackTrace,
    );
    previousPlatform?.call(safeError, stackTrace);
    return true;
  };

  return () {
    FlutterError.onError = previousFlutter;
    platform.onError = previousPlatform;
  };
}

// Keep the original object for ordinary errors. URL-bearing errors get a safe
// representation without retaining the raw object in anything sent to a sink.
Object _redactError(Object error) {
  final original = error.toString();
  final redacted = _redactText(original);
  if (original == redacted) return error;
  if (error is NetworkImageLoadException) {
    return NetworkImageLoadException(
      statusCode: error.statusCode,
      uri: Uri.parse(ApiLoggingInterceptor.redactUrl(error.uri.toString())),
    );
  }
  return _RedactedError(error.runtimeType.toString(), redacted);
}

DiagnosticsNode _redactDiagnostic(DiagnosticsNode node) {
  final original = _diagnosticText(node);
  final redacted = _redactText(original);
  return original == redacted ? node : ErrorDescription(redacted);
}

// Use unwrapped descriptions: toStringDeep is debug-only and may insert line
// breaks inside a credential-bearing URL before it can be redacted.
String _diagnosticText(DiagnosticsNode node) => [
  if (node.name == null)
    node.toDescription()
  else
    '${node.name}: ${node.toDescription()}',
  for (final child in [...node.getProperties(), ...node.getChildren()])
    _diagnosticText(child),
].join('\n');

String _redactText(String original) => original.replaceAllMapped(
  RegExp(
    r'(?:[A-Za-z][A-Za-z0-9+.\-]*:)?[/\\]{2}[^\s<>"]+'
    r'|(?:[A-Za-z0-9_~./%\-][^\s<>"?#]*)?[?#][^\s<>"]+',
  ),
  (match) {
    final candidate = match[0]!;
    // Error prose often wraps URLs in parentheses. Keep unmatched closing
    // delimiters outside the URL, while retaining balanced path parentheses.
    var end = candidate.length;
    final punctuation = RegExp(r'[.,;:!?]+$').firstMatch(candidate);
    if (punctuation != null) end = punctuation.start;
    var excess =
        ')'.allMatches(candidate).length - '('.allMatches(candidate).length;
    if (excess <= 0 || end == 0 || candidate[end - 1] != ')') {
      end = candidate.length;
    }
    while (excess > 0 && end > 0 && candidate[end - 1] == ')') {
      end--;
      excess--;
    }
    return ApiLoggingInterceptor.redactUrl(candidate.substring(0, end)) +
        candidate.substring(end);
  },
);

class _RedactedError implements Exception {
  const _RedactedError(this.type, this.description);

  final String type;
  final String description;

  @override
  String toString() => '$type: $description';
}
