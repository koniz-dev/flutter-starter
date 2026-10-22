/// How a `List<String>` is stored in a backend that only holds strings, such
/// as the Keychain/Keystore behind `SecureStorageService`.
///
/// Lists used to be joined with `,`, so an element containing a comma came
/// back as several elements and `['']` came back as `[]`.
/// They are now stored as a JSON array, which
/// is unambiguous for any string. Values written in the old comma form still
/// decode, with one accepted residual ambiguity - see [decodeStringList].
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
///
/// **One residual ambiguity, accepted**. JSON is tried first, so a legacy
/// value whose comma-joined text is *itself* a JSON array of strings decodes
/// as JSON: `['["x"]']`, written in the old form as the raw text `["x"]`, now
/// reads back as `['x']`, and the two-element
/// `['["a"', '"b"]']` (stored as `["a","b"]`) as `['a', 'b']`.
///
/// It is accepted rather than fixed because no encoding can rule it out. A
/// legacy value is an arbitrary string, so any marker a new encoding adds - a
/// version prefix, a sentinel character - is text some legacy value could
/// already hold, and values already written in this unmarked JSON form must
/// keep decoding too. A prefix would only move the ambiguity, not remove
/// it. Hitting it takes a legacy element that is literally JSON array syntax
/// with string items; the lists stored here hold identifiers and tokens.
List<String> decodeStringList(String raw) {
  final encoded = decodeEncodedStringList(raw);
  if (encoded != null) return encoded;
  if (raw.isEmpty) return <String>[];
  return raw.split(',');
}
