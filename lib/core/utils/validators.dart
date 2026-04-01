/// Validation utilities
class Validators {
  Validators._();

  /// Validate email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number (basic validation)
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Validate password length (at least 8 characters)
  static bool isValidPassword(String password) {
    return password.length >= 8;
  }

  /// Complex password validation (8+ chars, 1 uppercase, 1 lowercase, 1 number)
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    final hasUppercase = password.contains(RegExp('[A-Z]'));
    final hasDigits = password.contains(RegExp('[0-9]'));
    final hasLowercase = password.contains(RegExp('[a-z]'));
    final hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );
    return hasUppercase && hasDigits && hasLowercase && hasSpecialCharacters;
  }

  /// Check if string is numeric only
  static bool isNumeric(String s) {
    return RegExp(r'^-?[0-9]+$').hasMatch(s);
  }

  /// Check if string is alphanumeric only
  static bool isAlphaNumeric(String s) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(s);
  }

  /// Validate URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Check that URL has both scheme and non-empty authority
      return uri.hasScheme && uri.hasAuthority && uri.host.isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  /// Check if string is empty or null
  static bool isEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
