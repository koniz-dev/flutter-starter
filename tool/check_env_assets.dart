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
//     - assets/config/ # env-asset-ack: .env.web, app.env - publishable values
//
// The names are matched **exactly**, never as a substring: `.env.example` does
// not also acknowledge `.env`, and prose that merely mentions a file - even
// prose denying the file exists - acknowledges nothing. The whole grammar is
// on `parseAcknowledgedNames` below. An acknowledgement that names a file the
// directory does not hold is reported as a note on stderr and does not fail the
// run; see that function for why.
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
//     walk then covers it);
//   * whether an acknowledged file really is free of secrets. The marker
//     records that a human said so; nothing verifies the claim.
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

/// What ends the file-name list in an acknowledgement and starts free prose.
///
/// A semicolon, or an em or en dash, or a hyphen with whitespace on both sides.
/// None of them can occur inside a name accepted by [_ackName], so cutting here
/// never splits a file name.
final RegExp _ackProseSeparator = RegExp(r'[;\u2014\u2013]|\s-{1,2}(\s|$)');

/// One bare file name in an acknowledgement: no spaces, no path, no quotes.
///
/// It must contain a dot, which costs nothing: every name [secretAssetReason]
/// can flag has one (`.env`, `.env.*`, an extension from
/// [secretAssetExtensions], a name from [secretAssetNames]). Requiring it is
/// what lets a one-word comma segment such as `reviewed` read as prose rather
/// than as the name of a file that will never exist.
final RegExp _ackName = RegExp(r'^[A-Za-z0-9_+-]*\.[A-Za-z0-9._+-]*$');

/// The file names an `env-asset-ack:` [comment] covers, in written order.
///
/// The whole grammar:
///
///     ack       := 'env-asset-ack:' names? separator? prose?
///     names     := name (',' name)*
///     name      := a bare file name containing a dot, no spaces and no '/'
///     separator := ';' | em dash | en dash | ' - ' | the first ',' segment
///                  that is not a name
///
/// So the covered set is exactly the leading comma-separated run of bare file
/// names, and a reader can compute it by eye. Matching against a file is
/// **exact** and case-insensitive - see [AssetDeclaration.acknowledges].
///
/// Three consequences worth stating, because they are the point:
///
///   * `# env-asset-ack: .env.example, publishable placeholders only` covers
///     `.env.example` and nothing else. It does **not** cover `.env`, which a
///     substring test used to let through (koniz-dev/flutter-starter#170).
///   * `# env-asset-ack: .env.web only; there is no .env here` covers
///     *nothing*: the first segment is not a bare file name, so the list is
///     empty and the prose - including the `.env` inside it - is ignored. A
///     malformed acknowledgement fails closed rather than open.
///   * a name that matches no file in the directory is stale. That is a note on
///     stderr, not a failure: every `.env` is gitignored and a web deployment
///     may generate its env file at deploy time, so a fresh checkout can
///     legitimately lack the acknowledged file, and failing would red-light
///     clean CI runs on a tree that is strictly safer. A stale name cannot hide
///     a bundled secret either - the file it names is not there, and any file
///     that is there is matched exactly or reported.
List<String> parseAcknowledgedNames(String comment) {
  final marker = comment.indexOf(ackMarker);
  if (marker < 0) {
    return const <String>[];
  }

  var payload = comment.substring(marker + ackMarker.length);
  final prose = _ackProseSeparator.firstMatch(payload);
  if (prose != null) {
    payload = payload.substring(0, prose.start);
  }

  final names = <String>[];
  for (final segment in payload.split(',')) {
    final token = segment.trim();
    if (!_ackName.hasMatch(token)) {
      break;
    }
    names.add(token);
  }
  return names;
}

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

  /// File names this entry's acknowledgement covers. See
  /// [parseAcknowledgedNames] for the grammar.
  List<String> get acknowledgedNames => parseAcknowledgedNames(comment);

  /// Whether the entry carries an inline acknowledgement covering [fileName].
  ///
  /// A **file** entry acknowledges itself: the entry already names exactly one
  /// file, so the comment cannot widen what it covers and does not have to
  /// repeat the name.
  ///
  /// A **directory** entry has to name the file, and the name is compared
  /// **exactly** (case-insensitively), never as a substring. Every env file
  /// name is a prefix of a longer one, so the old substring test let
  /// `# env-asset-ack: .env.example` acknowledge a real `.env` as well
  /// (koniz-dev/flutter-starter#170).
  bool acknowledges(String fileName) {
    final marker = comment.indexOf(ackMarker);
    if (marker < 0) {
      return false;
    }
    if (!isDirectory) {
      return true;
    }
    final target = fileName.toLowerCase();
    return acknowledgedNames.any((name) => name.toLowerCase() == target);
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

/// A name in a directory acknowledgement that matches no file in that
/// directory.
///
/// Dead text rather than a live exception: the comment claims to cover a file
/// the tree does not hold. Reported, never fatal - see [parseAcknowledgedNames]
/// for why an absent file is not by itself an error.
class StaleAcknowledgement {
  /// Creates a finding for [name], acknowledged on [entry] at [line].
  const StaleAcknowledgement({
    required this.name,
    required this.entry,
    required this.line,
  });

  /// The file name the acknowledgement claims to cover.
  final String name;

  /// The declared directory the acknowledgement is written on.
  final String entry;

  /// 1-based line number of that declaration in the pubspec.
  final int line;
}

/// Names acknowledged on a declared directory that the directory does not hold.
///
/// [projectRoot] is the directory the asset paths are relative to. A declared
/// directory that does not exist makes every name on it stale; only files
/// directly inside it count, matching Flutter's own non-recursive bundling.
List<StaleAcknowledgement> findStaleAcknowledgements(
  String pubspecYaml, {
  required String projectRoot,
}) {
  final stale = <StaleAcknowledgement>[];

  for (final declaration in parseAssetDeclarations(pubspecYaml)) {
    if (!declaration.isDirectory) {
      continue;
    }
    final names = declaration.acknowledgedNames;
    if (names.isEmpty) {
      continue;
    }

    final directory = Directory('$projectRoot/${declaration.path}');
    final present = directory.existsSync()
        ? directory
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last.toLowerCase())
              .toSet()
        : const <String>{};

    for (final name in names) {
      if (!present.contains(name.toLowerCase())) {
        stale.add(
          StaleAcknowledgement(
            name: name,
            entry: declaration.path,
            line: declaration.line,
          ),
        );
      }
    }
  }

  return stale;
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

  // Advisories go to stderr, and none of them is load-bearing. The only thing
  // that can hide a bundled secret is a false PASS, and that is now an exit 1
  // below; what is left here is a reminder about files a human has already
  // signed off on, and acknowledgements that cover nothing at all. Stdout on a
  // passing run used to carry the real signal, which is exactly how
  // koniz-dev/flutter-starter#170 stayed quiet in CI.
  for (final f in findings.where((f) => f.acknowledged)) {
    stderr.writeln(
      'check_env_assets: $path:${f.line} bundles "${f.path}" with an '
      'acknowledgement. It ships in every build mode and is public - keep '
      'secrets out of it.',
    );
  }

  for (final stale in findStaleAcknowledgements(pubspec, projectRoot: root)) {
    stderr.writeln(
      'check_env_assets: note: $path:${stale.line} acknowledges '
      '"${stale.name}" in "${stale.entry}", which holds no such file. Drop the '
      'name if the file is gone; keep it if your deployment writes the file '
      'later.',
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

    - assets/config/ # $ackMarker app_config.env, .env.web - publishable only

The names are a comma-separated list of bare file names, each matched exactly
against the file name and never as a substring, ending at the first entry that
is not a file name; free prose may follow after a semicolon or a spaced dash.
So `.env.example` does not cover `.env`, and prose that merely mentions a file
does not acknowledge it.

See docs/guides/configuration.md ("Never ship a secret in the bundle").''')
    ..writeln();
  exit(1);
}
