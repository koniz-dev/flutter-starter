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
// Two ways a file gets bundled, and this tool checks both:
//
//   1. It is **named** in the asset list      -> findDeclaredSecretAssets
//   2. It sits inside a **directory** entry   -> findBundledDirectorySecrets
//
// A directory entry such as `- assets/config/` bundles every file directly
// inside it, so a `.env` dropped in there ships without any pubspec diff at
// all. `.env` is also gitignored, so review and secret scanners never see it
// either; the filesystem walk below is the only thing that does.
//
// What counts as a secrets file (see `secretAssetReason`): env files, private
// key and code-signing material by extension, and a short list of exact
// credential file names. It deliberately does **not** try to judge whether an
// arbitrary config file holds a secret - a rule that fired on `config.json`
// inside a directory literally named `assets/config/` would be wrong on its
// first run and would be deleted rather than fixed. Public certificates
// (`.cer`, `.crt`, `.der`) are likewise not flagged: a certificate is public by
// design and a pinning setup may legitimately ship one.
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
// For a file inside a declared directory the acknowledgement goes on the
// directory's line and must **name the file**, so one comment cannot silence a
// whole directory forever:
//
//   assets:
//     - assets/config/ # env-asset-ack: .env.web, publishable values only
//
// The acknowledgement has to be committed next to the entry, which is the
// opposite of shipping silently. An environment variable would not be.
//
// What this cannot catch:
//
//   * a file created after the check runs. The directory walk sees the tree as
//     it is at check time, and nothing re-runs it at build time - see
//     koniz-dev/flutter-starter#135 for the release-build path;
//   * a secret inside a file whose name looks innocuous. Matching is by name
//     only; nothing reads file contents;
//   * a secret in a *sub*-directory of a declared directory, which Flutter does
//     not bundle either (each sub-directory needs its own asset entry, and the
//     walk then covers it).
//
// Usage:
//   dart run tool/check_env_assets.dart                 # checks ./pubspec.yaml
//   dart run tool/check_env_assets.dart path/to/pubspec.yaml
//
// Directory entries are resolved relative to the pubspec's own directory, so
// pointing this at another checkout checks that checkout's files.
//
// Exits 0 when clean, 1 when an unacknowledged secrets file is bundled, 2 when
// the pubspec cannot be read.

import 'dart:io';

/// The one env file that is safe to ship: placeholders only.
const String allowedEnvAsset = '.env.example';

/// Marker that makes a bundled secrets file a reviewed, deliberate decision.
const String ackMarker = 'env-asset-ack:';

/// Lowercase extensions that are private key or code-signing material.
///
/// This mirrors the code-signing block of `.gitignore`, minus the public
/// certificate formats, plus `.pem` and `.key`. Bundling any of these into an
/// app is never correct: the app does not need the key that signs it, and a
/// private key in a shipped bundle is compromised the moment it ships.
const Set<String> secretAssetExtensions = <String>{
  '.jks',
  '.key',
  '.keystore',
  '.mobileprovision',
  '.p12',
  '.p8',
  '.pem',
  '.pfx',
  '.provisionprofile',
};

/// Lowercase file names that are credential stores by convention.
///
/// Kept to names that have no legitimate reason to be a Flutter asset. Anything
/// broader (`config.json`, `settings.yaml`) would fire on real configuration
/// and get the whole guard switched off.
const Set<String> secretAssetNames = <String>{
  'credentials.json',
  'google-services.json',
  'googleservice-info.plist',
  'key.properties',
  'secrets.json',
  'secrets.yaml',
  'secrets.yml',
  'service-account.json',
  'service_account.json',
};

/// Why [fileName] must not be bundled, or `null` when it is fine to ship.
///
/// Matching is on the file name alone, case-insensitively, and never on file
/// contents.
String? secretAssetReason(String fileName) {
  final name = fileName.toLowerCase();

  if (name == allowedEnvAsset) {
    return null;
  }
  if (name == '.env' || name.startsWith('.env.')) {
    return 'environment file';
  }

  final dot = name.lastIndexOf('.');
  if (dot >= 0 && secretAssetExtensions.contains(name.substring(dot))) {
    return 'private key or code-signing material';
  }
  if (secretAssetNames.contains(name)) {
    return 'credential file';
  }

  return null;
}

/// One `- path` line in the `flutter: assets:` list.
class AssetDeclaration {
  /// Creates a declaration of [path] written on [line] (1-based).
  const AssetDeclaration({
    required this.path,
    required this.line,
    required this.comment,
  });

  /// The asset path exactly as written in the pubspec, minus quotes.
  final String path;

  /// 1-based line number of the declaration.
  final int line;

  /// The trailing comment on that line, including the `#`, or `''`.
  final String comment;

  /// Whether Flutter treats this entry as a directory rather than a file.
  bool get isDirectory => path.endsWith('/');

  /// Whether the entry carries an inline acknowledgement covering [fileName].
  ///
  /// A directory acknowledgement has to name the file it covers; a file entry
  /// acknowledges itself.
  bool acknowledges(String fileName) {
    final marker = comment.indexOf(ackMarker);
    if (marker < 0) {
      return false;
    }
    if (!isDirectory) {
      return true;
    }
    return comment.substring(marker + ackMarker.length).contains(fileName);
  }
}

/// A file that the asset list bundles into every build and should not.
class BundledSecretAsset {
  /// Creates a finding for [path], bundled by the entry on [line].
  const BundledSecretAsset({
    required this.path,
    required this.entry,
    required this.line,
    required this.reason,
    required this.acknowledged,
  });

  /// Path of the offending file, relative to the project root.
  final String path;

  /// The asset entry that bundles it. Equal to [path] for a named file, and
  /// the declared directory when the file was found by walking one.
  final String entry;

  /// 1-based line number of the declaration in the pubspec.
  final int line;

  /// Short description of why this file must not ship, from
  /// [secretAssetReason].
  final String reason;

  /// Whether the declaration carries an inline [ackMarker] comment for it.
  final bool acknowledged;

  /// Whether the file was found by walking a declared directory.
  bool get viaDirectory => entry != path;
}

/// Every `- path` entry under `flutter: assets:` in [pubspecYaml].
///
/// This is a deliberately small hand-rolled scan rather than a YAML parse: the
/// inline acknowledgement lives in a comment, and a YAML parser throws comments
/// away.
List<AssetDeclaration> parseAssetDeclarations(String pubspecYaml) {
  final declarations = <AssetDeclaration>[];
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
        final declaration = _asDeclaration(raw, i + 1);
        if (declaration != null) {
          declarations.add(declaration);
        }
        continue;
      }
    }

    if (RegExp(r'^assets:\s*(#.*)?$').hasMatch(trimmed)) {
      assetsIndent = indent;
    }
  }

  return declarations;
}

/// Reads one `- path` line into an [AssetDeclaration].
AssetDeclaration? _asDeclaration(String rawLine, int lineNumber) {
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

  return AssetDeclaration(path: value, line: lineNumber, comment: comment);
}

/// Secrets files **named** in the asset list of [pubspecYaml].
///
/// Pure string analysis: it never touches the filesystem, so it sees only what
/// the pubspec spells out. Files inside a declared directory are invisible to
/// it by construction - that is what [findBundledDirectorySecrets] is for.
List<BundledSecretAsset> findDeclaredSecretAssets(String pubspecYaml) {
  final findings = <BundledSecretAsset>[];

  for (final declaration in parseAssetDeclarations(pubspecYaml)) {
    if (declaration.isDirectory) {
      continue;
    }
    final name = declaration.path.split('/').last;
    final reason = secretAssetReason(name);
    if (reason == null) {
      continue;
    }
    findings.add(
      BundledSecretAsset(
        path: declaration.path,
        entry: declaration.path,
        line: declaration.line,
        reason: reason,
        acknowledged: declaration.acknowledges(name),
      ),
    );
  }

  return findings;
}

/// Secrets files sitting inside a **directory** declared in [pubspecYaml].
///
/// [projectRoot] is the directory the asset paths are relative to, i.e. the one
/// holding the pubspec. The walk is non-recursive because Flutter's own
/// bundling is: a sub-directory ships only when it has its own asset entry, and
/// it is then walked in its own right.
///
/// This reports the tree as it is right now. A file dropped in afterwards ships
/// until something runs this again.
List<BundledSecretAsset> findBundledDirectorySecrets(
  String pubspecYaml, {
  required String projectRoot,
}) {
  final findings = <BundledSecretAsset>[];

  for (final declaration in parseAssetDeclarations(pubspecYaml)) {
    if (!declaration.isDirectory) {
      continue;
    }

    final directory = Directory('$projectRoot/${declaration.path}');
    if (!directory.existsSync()) {
      continue;
    }

    final entries = directory.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in entries) {
      final name = file.uri.pathSegments.last;
      final reason = secretAssetReason(name);
      if (reason == null) {
        continue;
      }
      findings.add(
        BundledSecretAsset(
          path: '${declaration.path}$name',
          entry: declaration.path,
          line: declaration.line,
          reason: reason,
          acknowledged: declaration.acknowledges(name),
        ),
      );
    }
  }

  return findings;
}

void main(List<String> args) {
  final path = args.isEmpty ? 'pubspec.yaml' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('check_env_assets: cannot read $path');
    exit(2);
  }

  final pubspec = file.readAsStringSync();
  final root = file.parent.path;
  final findings = <BundledSecretAsset>[
    ...findDeclaredSecretAssets(pubspec),
    ...findBundledDirectorySecrets(pubspec, projectRoot: root),
  ];
  final unacknowledged = findings.where((f) => !f.acknowledged).toList();

  for (final f in findings.where((f) => f.acknowledged)) {
    stdout.writeln(
      'check_env_assets: $path:${f.line} bundles "${f.path}" with an '
      'acknowledgement. It ships in every build mode and is public - keep '
      'secrets out of it.',
    );
  }

  if (unacknowledged.isEmpty) {
    stdout.writeln(
      'OK: no unacknowledged secrets file in the Flutter asset list, and none '
      'inside a declared asset directory.',
    );
    return;
  }

  stderr.writeln('SECURITY: a secrets file is bundled as a Flutter asset.\n');
  for (final f in unacknowledged) {
    final via = f.viaDirectory ? ' (via "${f.entry}")' : '';
    stderr.writeln('  $path:${f.line}  - ${f.path}$via  [${f.reason}]');
  }
  stderr
    ..writeln('''

Flutter asset lists are not build-mode scoped, so this file ships in the
release APK, the release IPA and the web build, not just in debug. Anyone can
unzip the app bundle to read it, and on web it is served over HTTP at
/assets/<path> and listed in AssetManifest.json. A declared *directory* bundles
everything directly inside it, with no pubspec entry per file.

Use instead:
  * native (all build modes): --dart-define-from-file=.env, or individual
    --dart-define flags. Nothing is bundled as a readable file.
  * web: there is no dart-define path, and a web client cannot hold a secret.
    Serve secrets from your backend and keep only publishable values in the
    bundle.
  * key and signing material: keep it out of the tree the app is built from.
    Nothing an app bundle contains is private.

If the file genuinely holds no secrets and must ship (a web build needing
runtime config), say so inline and this check will pass:

    - .env # $ackMarker web build, contains no secrets

For a file inside a declared directory, put the acknowledgement on the
directory entry and name the file, so it covers that file and not the whole
directory:

    - assets/config/ # $ackMarker app_config.env, publishable values only

See docs/guides/configuration.md ("Never ship a secret in the bundle").''')
    ..writeln();
  exit(1);
}
