import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_starter/core/localization/localization_extensions.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';

/// Service for announcing focus changes to screen readers
///
/// Helps improve navigation experience for users with screen readers
/// by announcing when focus moves to important elements.
class FocusAnnouncer {
  FocusAnnouncer._();

  /// Announce a message to screen readers
  ///
  /// Use this to provide feedback when focus changes or actions occur.
  ///
  /// The announcement is sent with the **active locale's** text direction, so
  /// an Arabic message is not handed to the platform as left-to-right text.
  static void announce(
    BuildContext context,
    String message, {
    bool assertiveness = false,
  }) {
    final view = View.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        message,
        textDirectionOf(context),
        assertiveness: assertiveness
            ? Assertiveness.assertive
            : Assertiveness.polite,
      ),
    );
  }

  /// Text direction to announce with for [context].
  ///
  /// Derived from the active locale via [LocalizationService.getTextDirection],
  /// falling back to the ambient [Directionality] when no [Localizations]
  /// scope is installed.
  @visibleForTesting
  static TextDirection textDirectionOf(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    if (locale != null) {
      return LocalizationService.getTextDirection(locale);
    }
    return Directionality.maybeOf(context) ?? TextDirection.ltr;
  }

  /// Announce a focus change
  ///
  /// Announces when focus moves to a new element.
  static void announceFocusChange(BuildContext context, String elementLabel) {
    announce(context, context.l10n.focusedOn(elementLabel));
  }

  /// Announce a page or screen change
  ///
  /// Announces when navigating to a new screen.
  static void announcePageChange(BuildContext context, String pageTitle) {
    announce(context, context.l10n.navigatedTo(pageTitle), assertiveness: true);
  }

  /// Announce an action result
  ///
  /// Announces the result of an action (success, error, etc.).
  ///
  /// [result] is passed through verbatim, so callers must supply an
  /// already-localized string.
  static void announceActionResult(BuildContext context, String result) {
    announce(context, result, assertiveness: true);
  }
}
