import 'dart:async';

import 'package:flutter/material.dart';

/// Minimal app shown when startup initialization fails
///
/// Startup runs storage migrations before the first frame. When that throws,
/// the alternative to this screen is no `runApp` call at all: a black window
/// on every launch, with nothing on screen explaining why and no way for the
/// user to retry.
///
/// Deliberately self-contained - no Riverpod scope, no router, no
/// localization. All three are initialized *after* the step that failed, so
/// none of them can be relied on here, which is why the copy is hard-coded
/// English rather than an `AppLocalizations` lookup.
class StartupFailureApp extends StatelessWidget {
  /// Creates a [StartupFailureApp] describing [error]
  ///
  /// [onRetry] is invoked when the user taps Try again; pass null to hide the
  /// button when retrying cannot help.
  const StartupFailureApp({required this.error, this.onRetry, super.key});

  /// The error that stopped startup
  final Object error;

  /// Called when the user asks to retry startup
  final Future<void> Function()? onRetry;

  /// Key on the failure screen body, for tests
  static const bodyKey = ValueKey<String>('startup_failure_body');

  /// Key on the retry action, for tests
  static const retryKey = ValueKey<String>('startup_failure_retry');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Starter',
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              key: bodyKey,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "Couldn't start the app",
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Local data could not be prepared. Nothing has been '
                    'deleted. Try again, and if this keeps happening, '
                    'reinstalling the app will start from empty local data.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text('$error', textAlign: TextAlign.center),
                  if (onRetry != null) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      key: retryKey,
                      onPressed: () => unawaited(onRetry!()),
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
