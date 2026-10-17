import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Body for the login and register forms: centred while the form fits, and
/// scrollable once it does not.
///
/// Both screens used to be a non-scrolling `Padding > Form > Column(center)`,
/// so a soft keyboard on a phone, or the phone turned to landscape, made the
/// column overflow and pushed the submit button off-screen where it could not
/// be reached (koniz-dev/flutter-starter#349). The minimum height keeps the
/// form vertically centred exactly as before whenever there is room.
class AuthFormBody extends StatelessWidget {
  /// Wraps [child], normally the screen's `Form`.
  const AuthFormBody({required this.child, super.key});

  /// Padding around the form, matching the screens' previous `Padding`.
  static const double padding = 16;

  /// The form.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 2 * padding),
          ),
          child: child,
        ),
      ),
    );
  }
}
