import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Service for announcing focus changes to screen readers
///
/// Helps improve navigation experience for users with screen readers
/// by announcing when focus moves to important elements.
class FocusAnnouncer {
  FocusAnnouncer._();

  /// Announce a message to screen readers
  ///
  /// Use this to provide feedback when focus changes or actions occur.
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
        TextDirection.ltr,
        assertiveness: assertiveness
            ? Assertiveness.assertive
            : Assertiveness.polite,
      ),
    );
  }

  /// Announce a focus change
  ///
  /// Announces when focus moves to a new element.
  static void announceFocusChange(
    BuildContext context,
    String elementLabel,
  ) {
    announce(context, 'Focused on $elementLabel');
  }

  /// Announce a page or screen change
  ///
  /// Announces when navigating to a new screen.
  static void announcePageChange(
    BuildContext context,
    String pageTitle,
  ) {
    announce(context, 'Navigated to $pageTitle', assertiveness: true);
  }

  /// Announce an action result
  ///
  /// Announces the result of an action (success, error, etc.).
  static void announceActionResult(
    BuildContext context,
    String result,
  ) {
    announce(context, result, assertiveness: true);
  }
}
