import 'package:flutter_starter/core/utils/validators.dart';

/// String extension methods
extension StringExtensions on String {
  /// Check if string is a valid email.
  ///
  /// Delegates to [Validators.isValidEmail] so the template ships exactly one
  /// email-validation behavior; this getter is only the ergonomic spelling.
  bool get isValidEmail => Validators.isValidEmail(this);

  /// Check if string is a valid phone number.
  ///
  /// Delegates to [Validators.isValidPhone].
  bool get isValidPhone => Validators.isValidPhone(this);

  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalize first letter of each word
  String get capitalizeWords {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Remove all whitespace
  String get removeWhitespace {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Check if string is empty or null
  bool get isNullOrEmpty {
    return isEmpty;
  }
}

/// Nullable String extension methods
extension NullableStringExtensions on String? {
  /// Check if string is null or empty
  bool get isNullOrEmpty {
    return this == null || this!.isEmpty;
  }

  /// Return empty string if null
  String get orEmpty {
    return this ?? '';
  }
}
