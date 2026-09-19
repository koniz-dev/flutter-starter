// Guard against bundling a secrets file as a Flutter asset.
//
// A Flutter `assets:` declaration is **not** build-mode scoped: there is no
// debug-only asset list. Anything listed there is copied into the release APK,
// the release IPA and the web build exactly as it is copied into a debug build.
// An `.env` declared as an asset is therefore:
//
//   * readable by anyone who unzips the shipped APK or IPA payload, and
//   * fetchable unauthenticated at `https://<host>/assets/.env` on web, where
//     it is also listed in `AssetManifest.json`.
//
// `.env.example` is exempt: it ships with every value blank or a placeholder,
// and `EnvConfig` needs at least one asset-backed env file to exist.
//
// Deliberate exception. A Flutter **web** build has no `--dart-define` path in
// this app (`EnvConfig` guards every dart-define read with `!kIsWeb`), so a web
// deployment that needs runtime configuration has no mechanism other than an
// asset-backed `.env`. That is allowed - but only for values you would publish,
// because a web client cannot hold a secret at all. To take that path,
// acknowledge it inline so it shows up in review:
//
//   assets:
//     - .env.example
//     - .env # env-asset-ack: web build, contains no secrets
//
// The acknowledgement has to be committed next to the entry, which is the
// opposite of shipping silently. An environment variable would not be.
//
// Usage:
//   dart run tool/check_env_assets.dart                 # checks ./pubspec.yaml
//   dart run tool/check_env_assets.dart path/to/pubspec.yaml
//
// Exits 0 when clean, 1 when an unacknowledged env file is bundled, 2 when the
// pubspec cannot be read.

import 'dart:io';

/// The one env file that is safe to ship: placeholders only.
const String allowedEnvAsset = '.env.example';

/// Marker that makes a bundled env file a reviewed, deliberate decision.
const String ackMarker = 'env-asset-ack:';

/// An `assets:` entry that would bundle an env file into every build.
class BundledEnvAsset {
  /// Creates a finding for [entry] declared on [line] (1-based).
  const BundledEnvAsset({
    required this.entry,
    required this.line,
    required this.acknowledged,
  });

  /// The asset path exactly as written in the pubspec, minus quotes.
  final String entry;

  /// 1-based line number of the declaration.
  final int line;

  /// Whether the declaration carries an inline [ackMarker] comment.
  final bool acknowledged;
}

/// Every env file declared under `flutter: assets:` in [pubspecYaml].
///
/// Returns both acknowledged and unacknowledged findings; only unacknowledged
/// ones are failures. `.env.example` is never reported.
///
/// This is a deliberately small hand-rolled scan rather than a YAML parse: the
/// inline acknowledgement lives in a comment, and a YAML parser throws comments
/// away.
List<BundledEnvAsset> findBundledEnvAssets(String pubspecYaml) {
  final findings = <BundledEnvAsset>[];
  final lines = pubspecYaml.split('\n');

  var inFlutterSection = false;
  var assetsIndent = -1;

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trim();

    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }

    final indent = raw.length - raw.trimLeft().length;

    // A new top-level key ends both the flutter section and any assets list.
    if (indent == 0) {
      inFlutterSection = RegExp(r'^flutter:\s*(#.*)?$').hasMatch(trimmed);
      assetsIndent = -1;
      continue;
    }

    if (!inFlutterSection) {
      continue;
    }

    if (assetsIndent >= 0) {
      final isListEntry = trimmed.startsWith('-');
      if (!isListEntry || indent <= assetsIndent) {
        // Dedented or switched to another key: the list is over.
        assetsIndent = -1;
      } else {
        final finding = _asEnvFinding(raw, i + 1);
        if (finding != null) {
          findings.add(finding);
        }
        continue;
      }
    }

    if (RegExp(r'^assets:\s*(#.*)?$').hasMatch(trimmed)) {
      assetsIndent = indent;
    }
  }

  return findings;
}

/// Reads one `- path` line and reports it when it bundles an env file.
BundledEnvAsset? _asEnvFinding(String rawLine, int lineNumber) {
  var value = rawLine.trim().substring(1).trim();

  // Split off a trailing comment, which is where the acknowledgement lives.
  var comment = '';
  final hash = value.indexOf('#');
  if (hash >= 0) {
    comment = value.substring(hash);
    value = value.substring(0, hash).trim();
  }

  value = value.replaceAll('"', '').replaceAll("'", '').trim();
  if (value.isEmpty) {
    return null;
  }

  final name = value.split('/').last;
  final isEnvFile = name == '.env' || name.startsWith('.env.');
  if (!isEnvFile || name == allowedEnvAsset) {
    return null;
  }

  return BundledEnvAsset(
    entry: value,
    line: lineNumber,
    acknowledged: comment.contains(ackMarker),
  );
}

void main(List<String> args) {
  final path = args.isEmpty ? 'pubspec.yaml' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('check_env_assets: cannot read $path');
    exit(2);
  }

  final findings = findBundledEnvAssets(file.readAsStringSync());
  final unacknowledged = findings.where((f) => !f.acknowledged).toList();

  for (final f in findings.where((f) => f.acknowledged)) {
    stdout.writeln(
      'check_env_assets: $path:${f.line} bundles "${f.entry}" with an '
      'acknowledgement. It ships in every build mode and is public - keep '
      'secrets out of it.',
    );
  }

  if (unacknowledged.isEmpty) {
    stdout.writeln('OK: no unacknowledged env file in the Flutter asset list.');
    return;
  }

  stderr.writeln('SECURITY: a secrets file is declared as a Flutter asset.\n');
  for (final f in unacknowledged) {
    stderr.writeln('  $path:${f.line}  - ${f.entry}');
  }
  stderr
    ..writeln('''

Flutter asset lists are not build-mode scoped, so this file ships in the
release APK, the release IPA and the web build, not just in debug. Anyone can
unzip the app bundle to read it, and on web it is served over HTTP at
/assets/.env and listed in AssetManifest.json.

Use instead:
  * native (all build modes): --dart-define-from-file=.env, or individual
    --dart-define flags. Nothing is bundled as a readable file.
  * web: there is no dart-define path, and a web client cannot hold a secret.
    Serve secrets from your backend and keep only publishable values in the
    bundle.

If the file genuinely holds no secrets and must ship (a web build needing
runtime config), say so inline and this check will pass:

    - .env # $ackMarker web build, contains no secrets

See docs/guides/configuration.md ("Never ship a secret in the bundle").''')
    ..writeln();
  exit(1);
}
