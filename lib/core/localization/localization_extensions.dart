import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// Localization helpers on [BuildContext].
extension LocalizationContextExtensions on BuildContext {
  /// Localized strings for this context.
  ///
  /// Every user-visible and screen-reader string in `lib/shared/` and
  /// `lib/core/accessibility/` goes through this getter, so there is exactly
  /// one path from the ARB files to the widget tree.
  ///
  /// When no [AppLocalizations] delegate is installed above this context -
  /// which happens in widget tests that pump a bare `MaterialApp` - this falls
  /// back to the strings of [LocalizationService.defaultLocale] instead of
  /// throwing. The fallback still comes from the ARBs; it is never a hardcoded
  /// literal.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(LocalizationService.defaultLocale);
}
