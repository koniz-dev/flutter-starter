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
// Both read the list through `parseAssetDeclarations`, a real YAML parse, so
// every spelling Flutter accepts counts: `- .env`, the map form `- path: .env`
// (which `flavors:` and `transformers:` need), a flow list `[.env.example,
// .env]`, and `deferred-components:` asset lists.
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
// Deliberate exception. `--dart-define-from-file` configures a build on every
// target, Flutter web included. A bundled
// `.env` remains an option only for configuration that must change *without a
// rebuild* - an asset can be swapped at deploy time - and only for values you
// would publish, because whatever the app bundles, its users can read. To take
// that path, acknowledge it inline so it shows up in review:
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
// On a map-form entry the acknowledgement goes on the `path:` line. In a flow
// list several entries share one comment, so there it must name each file it
// covers, exactly as on a directory.
//
// The acknowledgement has to be committed next to the entry, which is the
// opposite of shipping silently. An environment variable would not be.
//
// What this cannot catch:
//
//   * a file created after the check runs. The directory walk sees the tree as
//     it is at check time. The build scripts and deploy workflows run it
//     again just before building, but nothing re-runs it during the build;
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
// the pubspec cannot be read or its asset list is in a shape this check cannot
// read for certain - it fails closed rather than report a list it never read.

import 'dart:io';
import 'dart:io' as io show stderr, stdout;

import 'package:yaml/yaml.dart';

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
/// can flag has one (`.env` and its `.env.*`, `.env-*`, `.env_*`, `.envrc*`
/// and `*.env` spellings, an extension from [secretAssetExtensions], a name
/// from [secretAssetNames]). Requiring it is
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
///     substring test used to let through.
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
  // `.env` and its variants (`.env.production`, `.env-staging`, `.env_prod`,
  // `.envrc`), and any `<name>.env` such as `production.env` or
  // `app_config.env`.
  if (name == '.env' ||
      name.startsWith('.env.') ||
      name.startsWith('.env-') ||
      name.startsWith('.env_') ||
      name.startsWith('.envrc') ||
      name.endsWith('.env')) {
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

/// One entry in a Flutter asset list: `- path`, `- path: path`, or one item
/// of a flow list.
class AssetDeclaration {
  /// Creates a declaration of [path] written on [line] (1-based).
  const AssetDeclaration({
    required this.path,
    required this.line,
    required this.comment,
    this.sharesLine = false,
  });

  /// The asset path exactly as written in the pubspec, minus quotes.
  final String path;

  /// 1-based line number of the declaration.
  final int line;

  /// The trailing comment on that line, including the `#`, or `''`.
  final String comment;

  /// Whether another asset entry is written on the same line, as in a flow
  /// list such as `assets: [.env.example, .env]`.
  final bool sharesLine;

  /// Whether Flutter treats this entry as a directory rather than a file.
  bool get isDirectory => path.endsWith('/');

  /// File names this entry's acknowledgement covers. See
  /// [parseAcknowledgedNames] for the grammar.
  List<String> get acknowledgedNames => parseAcknowledgedNames(comment);

  /// Whether the entry carries an inline acknowledgement covering [fileName].
  ///
  /// A **file** entry alone on its line acknowledges itself: the entry already
  /// names exactly one file, so the comment cannot widen what it covers and
  /// does not have to repeat the name.
  ///
  /// A file entry that [sharesLine] with others shares the comment too, so it
  /// has to be named in it, exactly like a file in a directory: otherwise one
  /// comment on `[.env.example, .env]` would cover both.
  ///
  /// A **directory** entry has to name the file, and the name is compared
  /// **exactly** (case-insensitively), never as a substring. Every env file
  /// name is a prefix of a longer one, so the old substring test let
  /// `# env-asset-ack: .env.example` acknowledge a real `.env` as well.
  bool acknowledges(String fileName) {
    final marker = comment.indexOf(ackMarker);
    if (marker < 0) {
      return false;
    }
    if (!isDirectory && !sharesLine) {
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

/// Raised when the pubspec, or the part of it that lists assets, is not
/// something this check can read with certainty.
///
/// The check fails **closed** on it: `main` exits 2 rather than reporting a
/// clean tree it never actually read. A guard that shrugs at a shape it does
/// not recognise is how map-form and flow-style entries shipped a `.env` past
/// it.
class AssetListFormatException implements Exception {
  /// Creates the exception for [message], about the pubspec's 1-based [line].
  const AssetListFormatException(this.message, {this.line});

  /// What could not be read.
  final String message;

  /// 1-based line in the pubspec, or `null` when the problem has no one line.
  final int? line;

  @override
  String toString() => line == null ? message : 'line $line: $message';
}

/// Every asset entry Flutter bundles from [pubspecYaml], in written order.
///
/// Two passes, because neither alone is enough:
///
///   1. **Structure** comes from a real YAML parse, so every spelling Flutter
///      accepts is seen: block lists (`- .env`), flow lists
///      (`assets: [.env.example, .env]`) and map-form entries
///      (`- path: .env`, the form `flavors:` and `transformers:` need).
///      `deferred-components:` asset lists are read too - they bundle files
///      just the same.
///   2. **Comments** come from the raw text at each path's source span, because
///      a YAML parser throws comments away and the acknowledgement lives in
///      one. The comment is the one on the line where the path itself is
///      written: for a map-form entry, the `path:` line.
///
/// Throws [AssetListFormatException] for anything it cannot read for certain:
/// invalid YAML, an asset list that is not a list, or an entry that is not a
/// path string or a map with one. Guessing there would be failing open.
List<AssetDeclaration> parseAssetDeclarations(String pubspecYaml) {
  final YamlNode document;
  try {
    document = loadYamlNode(pubspecYaml);
  } on YamlException catch (e) {
    throw AssetListFormatException(
      'not valid YAML: ${e.message}',
      line: e.span == null ? null : e.span!.start.line + 1,
    );
  }

  if (document.value == null) {
    return const <AssetDeclaration>[];
  }
  if (document is! YamlMap) {
    throw _formatError(document, 'the pubspec is not a YAML map');
  }

  final flutter = document.nodes['flutter'];
  if (flutter == null || flutter.value == null) {
    return const <AssetDeclaration>[];
  }
  if (flutter is! YamlMap) {
    throw _formatError(flutter, '`flutter:` is not a map');
  }

  final lines = pubspecYaml.split('\n');
  final declarations = <AssetDeclaration>[
    ..._readAssetList(flutter.nodes['assets'], 'flutter: assets:', lines),
  ];

  final deferred = flutter.nodes['deferred-components'];
  if (deferred != null && deferred.value != null) {
    if (deferred is! YamlList) {
      throw _formatError(deferred, '`deferred-components:` is not a list');
    }
    for (final component in deferred.nodes) {
      if (component is! YamlMap) {
        throw _formatError(component, 'a deferred component is not a map');
      }
      declarations.addAll(
        _readAssetList(
          component.nodes['assets'],
          'deferred-components: assets:',
          lines,
        ),
      );
    }
  }

  // An entry that shares its line with another entry (a flow list) does not
  // acknowledge itself: one comment would otherwise silence every file in
  // `[.env.example, .env, .env.prod] # env-asset-ack: ...` at once.
  final perLine = <int, int>{};
  for (final d in declarations) {
    perLine[d.line] = (perLine[d.line] ?? 0) + 1;
  }
  return <AssetDeclaration>[
    for (final d in declarations)
      AssetDeclaration(
        path: d.path,
        line: d.line,
        comment: d.comment,
        sharesLine: perLine[d.line]! > 1,
      ),
  ];
}

/// The entries of one `assets:` list, or none when [node] is absent or empty.
List<AssetDeclaration> _readAssetList(
  YamlNode? node,
  String where,
  List<String> lines,
) {
  if (node == null || node.value == null) {
    return const <AssetDeclaration>[];
  }
  if (node is! YamlList) {
    throw _formatError(node, '`$where` is not a list');
  }

  final declarations = <AssetDeclaration>[];
  for (final entry in node.nodes) {
    var pathNode = entry;
    if (entry is YamlMap) {
      final path = entry.nodes['path'];
      if (path == null) {
        throw _formatError(entry, 'a map-form `$where` entry has no `path:`');
      }
      pathNode = path;
    }

    final value = pathNode.value;
    if (pathNode is! YamlScalar || value is! String || value.trim().isEmpty) {
      throw _formatError(
        pathNode,
        'a `$where` entry is not a path string: ${pathNode.span.text}',
      );
    }

    final endLine = pathNode.span.end.line;
    declarations.add(
      AssetDeclaration(
        path: value.trim(),
        line: pathNode.span.start.line + 1,
        comment: endLine < lines.length
            ? _trailingComment(lines[endLine], pathNode.span.end.column)
            : '',
      ),
    );
  }
  return declarations;
}

/// The YAML comment on [line] after column [from], including the `#`, or `''`.
///
/// A `#` starts a comment only after whitespace and outside quotes, which is
/// the YAML rule, so `- "a#b"` or a later quoted flow entry cannot open one.
String _trailingComment(String line, int from) {
  String? quote;
  for (var i = from; i < line.length; i++) {
    final char = line[i];
    if (quote != null) {
      if (char == quote) {
        quote = null;
      }
    } else if (char == '"' || char == "'") {
      quote = char;
    } else if (char == '#' &&
        (i == 0 || line[i - 1] == ' ' || line[i - 1] == '\t')) {
      return line.substring(i).trimRight();
    }
  }
  return '';
}

AssetListFormatException _formatError(YamlNode node, String message) =>
    AssetListFormatException(message, line: node.span.start.line + 1);

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

void main(List<String> args) => exit(run(args));

/// The whole check, minus the process exit, so a test can assert the exit
/// code `main` would return. Writes to [out] and [err], which default to
/// stdout and stderr.
int run(List<String> args, {StringSink? out, StringSink? err}) {
  final stdout = out ?? io.stdout;
  final stderr = err ?? io.stderr;
  final path = args.isEmpty ? 'pubspec.yaml' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('check_env_assets: cannot read $path');
    return 2;
  }

  final pubspec = file.readAsStringSync();
  final root = file.parent.path;
  final List<BundledSecretAsset> findings;
  try {
    findings = <BundledSecretAsset>[
      ...findDeclaredSecretAssets(pubspec),
      ...findBundledDirectorySecrets(pubspec, projectRoot: root),
    ];
  } on AssetListFormatException catch (e) {
    stderr.writeln(
      'check_env_assets: cannot read the asset list in $path ($e). Refusing '
      'to report it clean: fix the pubspec so `flutter pub get` accepts it.',
    );
    return 2;
  }
  final unacknowledged = findings.where((f) => !f.acknowledged).toList();

  // Advisories go to stderr, and none of them is load-bearing. The only thing
  // that can hide a bundled secret is a false PASS, and that is now an exit 1
  // below; what is left here is a reminder about files a human has already
  // signed off on, and acknowledgements that cover nothing at all. Stdout on a
  // passing run used to carry the real signal, which is exactly how an
  // over-broad acknowledgement once stayed quiet in CI.
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
    return 0;
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

Use instead, on every target (Android, iOS, desktop and web alike):
  * --dart-define-from-file=.env, or individual --dart-define flags. Nothing
    is bundled as a readable file. These are build configuration, not a
    secret store: the values are recoverable from the binary, and on web
    from the downloaded JavaScript.
  * secrets: serve them from your backend at run time and keep only
    publishable values in the app.
  * key and signing material: keep it out of the tree the app is built from.
    Nothing an app bundle contains is private.

If the file genuinely holds no secrets and must ship (publishable config that
has to change without a rebuild), say so inline and this check will pass:

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
  return 1;
}
