import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/utils/validators.dart';
import 'package:flutter_starter/features/auth/demo/demo_auth.dart';
import 'package:flutter_starter/features/auth/demo/demo_sign_in_card.dart';
import 'package:flutter_starter/features/auth/presentation/auth_redirect.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/widgets/auth_form_body.dart';
import 'package:flutter_starter/features/auth/presentation/widgets/password_form_field.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Login screen for user authentication
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates a [LoginScreen] widget
  const LoginScreen({super.key, this.redirect});

  /// The deep link the router guard parked on this route, if any, carried
  /// on to the other auth screen.
  final String? redirect;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // The keyboard's Done reaches here too: not while a request is running.
    if (ref.read(authNotifierProvider).isLoading) return;
    if (_formKey.currentState!.validate()) {
      await ref
          .read(authNotifierProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
      // The screen can be popped while the request runs; `ref` is unusable
      // after that.
      if (!mounted) return;
      // Lets the platform's password manager offer to save the credentials,
      // on success only.
      if (ref.read(authNotifierProvider).user != null) {
        TextInput.finishAutofillContext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.login)),
      body: AuthFormBody(
        child: Form(
          key: _formKey,
          // Cancel, not the default commit, when the form goes away: leaving
          // after a failed sign-in offered to save rejected credentials.
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (DemoAuth.enabled) ...[
                  DemoSignInCard(
                    onFill: () {
                      _emailController.text = DemoAuth.email;
                      _passwordController.text = DemoAuth.password;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return l10n.emailRequired;
                    }
                    if (!Validators.isValidEmail(email)) {
                      return l10n.emailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PasswordFormField(
                  controller: _passwordController,
                  labelText: l10n.password,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordRequired;
                    }
                    if (!Validators.isValidPassword(value)) {
                      return l10n.passwordMinLength(8);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (authState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    // A live region, so a screen reader announces the
                    // failure: focus stays on the submit button.
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        // The failure in the user's language, never the log
                        // text in `error`.
                        authState.failure?.localizedMessage(l10n) ??
                            authState.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: UiKeys.loginSubmit,
                  onPressed: authState.isLoading ? null : _handleLogin,
                  child: authState.isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          // The spinner alone would leave the button nameless.
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: l10n.login,
                          ),
                        )
                      : Text(l10n.login),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          ref.read(authNotifierProvider.notifier).clearError();
                          context.replaceRoute(
                            authLocationKeepingRedirect(
                              AppRoutes.register,
                              widget.redirect,
                            ),
                          );
                        },
                  child: Text(l10n.dontHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
