import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A password [TextFormField] with a show/hide toggle.
///
/// The auth forms had no way to check a typed password, so a typo on a
/// phone keyboard meant a failed sign-in with no clue why.
class PasswordFormField extends StatefulWidget {
  /// Creates a [PasswordFormField].
  const PasswordFormField({
    required this.controller,
    required this.labelText,
    required this.autofillHints,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    super.key,
  });

  /// The field's text.
  final TextEditingController controller;

  /// The field's label.
  final String labelText;

  /// `AutofillHints.password` to sign in, `AutofillHints.newPassword` to
  /// register (which lets the platform offer a generated password).
  final Iterable<String> autofillHints;

  /// Validates the value, as a `TextFormField` validator does.
  final FormFieldValidator<String>? validator;

  /// The keyboard's action button: next, or done to submit.
  final TextInputAction? textInputAction;

  /// Called on the keyboard's action button.
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
