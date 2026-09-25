import 'dart:convert';

/// Validation utilities
///
/// ## Email standard
///
/// [isValidEmail] validates against the RFC 5322 `addr-spec` grammar
/// restricted to its `dot-atom` form, widened to internationalised addresses
/// per RFC 6531 (SMTPUTF8) and bounded by the RFC 5321 size limits.
///
/// Accepted:
///
/// - a `dot-atom` local part: one or more `atext` runs joined by single dots,
///   so no leading, trailing, or consecutive dots
/// - non-ASCII `atext` (U+0080 and above) in both parts, so
///   `jose@example.com` spelled with an accented `e` and U-label domains
///   validate
/// - a domain of two or more LDH labels (RFC 1035 preferred syntax): each
///   label 1-63 octets, alphanumeric at both ends, hyphens only inside
/// - a final label (TLD) of at least two characters starting with a letter,
///   so punycode TLDs such as `xn--p1ai` validate
/// - RFC 5321 limits: local part at most 64 octets, whole address at most
///   254 octets
///
/// Deliberately rejected, even though RFC 5322 permits them. Each is
/// unusable in a sign-up form, and accepting it costs more than the
/// near-zero chance of a real user typing one:
///
/// - quoted-string local parts, e.g. a local part wrapped in double quotes
///   containing a space
/// - domain literals, e.g. an IP address in square brackets
/// - comments and folding whitespace
/// - single-label domains such as `user@localhost`
/// - a trailing root dot, e.g. `user@example.com.`
///
/// Over-strictness is a bug too: rejecting a legitimate address is worse for
/// a user than accepting a malformed one. Everything above is rejected
/// because an address of that shape cannot be delivered by the public mail
/// system, not because the pattern was easier to write that way.
class Validators {
  Validators._();

  /// `atext` per RFC 5322 section 3.2.3, plus non-ASCII per RFC 6531.
  static const String _atext = r"A-Za-z0-9!#$%&'*+/=?^_`{|}~\u0080-\uFFFF-";

  /// Local part: `dot-atom` - `atext` runs separated by single dots.
  static final RegExp _emailLocalPart = RegExp(
    '^[$_atext]+(?:\\.[$_atext]+)*\$',
  );

  /// Domain: two or more LDH labels, the last starting with a letter.
  static final RegExp _emailDomain = RegExp(
    r'^(?:[A-Za-z0-9\u0080-\uFFFF]'
    r'(?:[A-Za-z0-9\u0080-\uFFFF-]{0,61}[A-Za-z0-9\u0080-\uFFFF])?\.)+'
    r'[A-Za-z\u0080-\uFFFF]'
    r'[A-Za-z0-9\u0080-\uFFFF-]{0,61}'
    r'[A-Za-z0-9\u0080-\uFFFF]$',
  );

  /// Maximum length of the local part in octets (RFC 5321 section 4.5.3.1.1).
  static const int _maxLocalPartOctets = 64;

  /// Maximum length of the whole address in octets, the practical limit
  /// implied by the 256-octet `Path` cap in RFC 5321 section 4.5.3.1.3.
  static const int _maxAddressOctets = 254;

  /// Maximum length of a single DNS label (RFC 1035 section 2.3.4).
  static const int _maxLabelOctets = 63;

  /// Validate an email address.
  ///
  /// See the class-level "Email standard" section for exactly what is
  /// accepted and what is deliberately rejected.
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    if (utf8.encode(email).length > _maxAddressOctets) return false;

    // A `dot-atom` local part cannot contain '@', so a valid address has
    // exactly one.
    final parts = email.split('@');
    if (parts.length != 2) return false;

    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty || domain.isEmpty) return false;
    if (utf8.encode(local).length > _maxLocalPartOctets) return false;

    if (!_emailLocalPart.hasMatch(local)) return false;
    if (!_emailDomain.hasMatch(domain)) return false;

    for (final label in domain.split('.')) {
      if (utf8.encode(label).length > _maxLabelOctets) return false;
    }
    return true;
  }

  /// Validate phone number (basic validation)
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Validate password length (at least 8 characters)
  ///
  /// This is a length check and nothing more. It is what the sample auth
  /// screens use. For a composition policy, see [isStrongPassword].
  static bool isValidPassword(String password) {
    return password.length >= 8;
  }

  /// Complex password validation.
  ///
  /// Returns true only when [password] is 8 or more characters long and
  /// contains at least one of each of the following:
  ///
  /// - an uppercase letter (`A-Z`)
  /// - a lowercase letter (`a-z`)
  /// - a digit (`0-9`)
  /// - a character that is none of the above, which includes punctuation,
  ///   symbols, the space character, and any non-ASCII character
  ///
  /// The special-character requirement stays, but the character class is now
  /// the complement of `[A-Za-z0-9]` instead of a hand-written list. The old
  /// list omitted `_`, `-`, `+`, `=`, `[`, `]`, `;`, `/`, `\`, `~` and space,
  /// so `Passw0rd_` was rejected while the doc comment promised otherwise.
  ///
  /// This is **not** what the sample auth screens use; they use
  /// [isValidPassword]. NIST SP 800-63B section 3.1.1.2 advises against
  /// imposing composition rules, so the template does not impose one by
  /// default. Opt in from your own form validator if your policy requires it.
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    final hasUppercase = password.contains(RegExp('[A-Z]'));
    final hasDigits = password.contains(RegExp('[0-9]'));
    final hasLowercase = password.contains(RegExp('[a-z]'));
    final hasSpecialCharacters = password.contains(RegExp('[^A-Za-z0-9]'));
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
