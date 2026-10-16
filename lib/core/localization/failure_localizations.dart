import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// The text a screen shows for a [Failure], in the user's language.
///
/// [Failure.message] is built for logs, not people: `DioExceptionMapper`
/// writes it in English and often appends dio's own wording ("This indicates
/// an error which most likely cannot be solved by the library"), and a
/// `ServerFailure` carries whatever the backend sent. Rendering it bypassed
/// the ARB pipeline, so a Vietnamese or Arabic user saw English transport
/// text (koniz-dev/flutter-starter#323).
///
/// This never returns [Failure.message]. It maps the stable [Failure.code]
/// values the app itself produces, then falls back to the [Failure] subtype,
/// then to a generic message. Codes a backend invents are deliberately not
/// mapped here: add an entry when your API documents one.
///
/// ```dart
/// Text(failure.localizedMessage(context.l10n))
/// ```
extension FailureLocalizations on Failure {
  /// This failure's user-facing message in the language of [l10n].
  String localizedMessage(AppLocalizations l10n) {
    switch (code) {
      case 'CONNECTION_TIMEOUT':
      case 'SEND_TIMEOUT':
      case 'RECEIVE_TIMEOUT':
        return l10n.failureTimeout;
      case 'CONNECTION_ERROR':
      case 'NETWORK_ERROR':
      case 'UNKNOWN_NETWORK_ERROR':
        return l10n.failureNoConnection;
      case 'BAD_CERTIFICATE':
        return l10n.failureInsecureConnection;
      case 'REQUEST_CANCELLED':
        return l10n.failureCancelled;
      case 'INVALID_AUTH_RESPONSE':
        return l10n.failureUnreadableResponse;
    }
    return switch (this) {
      NetworkFailure() => l10n.failureNoConnection,
      AuthFailure() => l10n.failureAuth,
      PermissionFailure() => l10n.failurePermission,
      NotFoundFailure() => l10n.failureNotFound,
      ValidationFailure() => l10n.failureValidation,
      CacheFailure() => l10n.failureStorage,
      ServerFailure() => l10n.failureServer,
      _ => l10n.failureUnknown,
    };
  }
}
