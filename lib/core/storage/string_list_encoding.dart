/// How a `List<String>` is stored in a backend that only holds strings, such
/// as the Keychain/Keystore behind `SecureStorageService`.
///
/// Lists used to be joined with `,`, so an element containing a comma came
/// back as several elements and `['']` came back as `[]`
/// (koniz-dev/flutter-starter#281). They are now stored as a JSON array, which
/// is unambiguous for any string. Values written in the old comma form still
/// decode - see [decodeStringList].
library;

import 'dart:convert';

/// Encodes [list] as a JSON array.
String encodeStringList(List<String> list) => jsonEncode(list);

/// [raw] decoded as a JSON array of strings, or `null` when it is not one.
///
/// This is how a reader tells a value written by [encodeStringList] apart
/// from a plain string - for example a migration that must not split an
/// already-migrated list a second time.
List<String>? decodeEncodedStringList(String raw) {
  if (!raw.startsWith('[')) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List && decoded.every((e) => e is String)) {
      return decoded.cast<String>();
    }
  } on FormatException {
    // Not JSON: a legacy comma-joined value that happens to start with '['.
  }
  return null;
}

/// Decodes a stored list: the JSON form, or the legacy comma-joined form
/// (where `''` is the empty list).
List<String> decodeStringList(String raw) {
  final encoded = decodeEncodedStringList(raw);
  if (encoded != null) return encoded;
  if (raw.isEmpty) return <String>[];
  return raw.split(',');
}
