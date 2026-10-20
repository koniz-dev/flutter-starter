// Documentation integrity checker.
//
// Seven checks, all of which have silently rotted in this repository before:
//
//   1. Relative links and heading anchors resolve, without leaving the
//      repository, in README.md, CONTRIBUTING.md, CHANGELOG.md and the
//      markdown under `docs/`, `test/`, `scripts/`, `tool/`, `bricks/`,
//      `examples/`, `integration_test/` and `fastlane/`.
//   2. No emoji in `docs/`, `CLAUDE.md`, or `.claude/` (the stated convention
//      in CLAUDE.md; `README.md` and `CONTRIBUTING.md` are deliberately
//      exempt because they predate it).
//   3. Documented constructor signatures match their source, for every
//      fenced block carrying a `<!-- signature: <path> <Name> -->` directive
//      (see `tool/doc_signatures.dart`).
//   4. Every identifier asserted with a `<!-- symbol: <path> <name> -->`
//      directive is actually declared in that file
//      (see `tool/doc_symbols.dart`). Check 3 is the strong form and needs a
//      signature block; this is the weak, broad one, and it is the one that
//      would have caught `contracts-map.md` citing a provider that never
//      existed (koniz-dev/flutter-starter#206).
//   5. Setup steps that `cp .env.example .env` then run `flutter run` or
//      `flutter build` pass `--dart-define-from-file`, in README.md,
//      CONTRIBUTING.md and `docs/` (see `tool/doc_env_runs.dart`,
//      koniz-dev/flutter-starter#355).
//   6. Every `--dart-define` key in a fenced block of README.md or `docs/` is
//      a key of `DartDefines.values`, so no guide passes a flag the app never
//      reads (see `tool/doc_dart_defines.dart`,
//      koniz-dev/flutter-starter#379).
//   7. Every `flutter test <path>` in a fenced block of README.md,
//      CONTRIBUTING.md or `docs/` names a file or directory that exists
//      (see `tool/doc_test_paths.dart`, koniz-dev/flutter-starter#551).
//
// Usage:
//   dart run tool/check_docs.dart               # all checks
//   dart run tool/check_docs.dart --links       # links and anchors only
//   dart run tool/check_docs.dart --emoji       # emoji only
//   dart run tool/check_docs.dart --signatures  # constructor signatures only
//   dart run tool/check_docs.dart --symbols     # symbol existence only
//   dart run tool/check_docs.dart --env-runs    # .env setup runs only
//   dart run tool/check_docs.dart --dart-defines  # --dart-define keys only
//   dart run tool/check_docs.dart --test-paths  # flutter test paths only
//
// Exits 0 when clean, 1 when anything is broken.

import 'dart:io';

import 'doc_dart_defines.dart';
import 'doc_env_runs.dart';
import 'doc_signatures.dart';
import 'doc_symbols.dart';
import 'doc_test_paths.dart';

void main(List<String> args) {
  final linksOnly = args.contains('--links');
  final emojiOnly = args.contains('--emoji');
  final signaturesOnly = args.contains('--signatures');
  final symbolsOnly = args.contains('--symbols');
  final envRunsOnly = args.contains('--env-runs');
  final dartDefinesOnly = args.contains('--dart-defines');
  final testPathsOnly = args.contains('--test-paths');
  final anyFilter =
      linksOnly ||
      emojiOnly ||
      signaturesOnly ||
      symbolsOnly ||
      envRunsOnly ||
      dartDefinesOnly ||
      testPathsOnly;
  final runLinks = !anyFilter || linksOnly;
  final runEmoji = !anyFilter || emojiOnly;
  final runSignatures = !anyFilter || signaturesOnly;
  final runSymbols = !anyFilter || symbolsOnly;
  final runEnvRuns = !anyFilter || envRunsOnly;
  final runDartDefines = !anyFilter || dartDefinesOnly;
  final runTestPaths = !anyFilter || testPathsOnly;

  final root = Directory.current;
  var failures = 0;

  if (runLinks) {
    failures += _checkLinks(root);
  }
  if (runEmoji) {
    failures += _checkEmoji(root);
  }
  if (runSignatures) {
    failures += checkSignatures(root);
  }
  if (runSymbols) {
    failures += checkSymbols(root);
  }
  if (runEnvRuns) {
    failures += checkEnvRuns(root);
  }
  if (runDartDefines) {
    failures += checkDartDefines(root);
  }
  if (runTestPaths) {
    failures += checkTestPaths(root);
  }

  if (failures > 0) {
    stderr.writeln('\n$failures problem(s) found.');
    exit(1);
  }
  stdout.writeln('\nOK: documentation checks passed.');
}

// ===========================================================================
// Links and anchors
// ===========================================================================

int _checkLinks(Directory root) {
  final docs = Directory('${root.path}/docs');
  if (!docs.existsSync()) {
    stderr.writeln('docs/ not found; run from the repository root.');
    return 1;
  }

  final files = _linkScanFiles(root);

  final anchorCache = <String, Set<String>>{};
  var broken = 0;
  var checked = 0;

  for (final file in files) {
    final source = file.readAsStringSync();
    final body = _stripCodeBlocks(source);

    for (final link in _inlineLinks(body)) {
      final target = link.target;
      if (target.isEmpty) continue;
      if (_isExternal(target)) continue;

      checked++;

      final hashIndex = target.indexOf('#');
      final pathPart = hashIndex < 0 ? target : target.substring(0, hashIndex);
      final fragment = hashIndex < 0 ? '' : target.substring(hashIndex + 1);

      String resolved;
      if (pathPart.isEmpty) {
        resolved = file.path;
      } else {
        resolved = _normalize('${_dirname(file.path)}/${_decode(pathPart)}');
        // A link that leaves the checkout can resolve on one machine and
        // nowhere else - test/README.md had four (koniz-dev/flutter-starter#573).
        if (resolved != root.path && !resolved.startsWith('${root.path}/')) {
          broken++;
          stderr.writeln(
            '${_rel(root, file.path)}:${link.line}: escapes the repository '
            '-> $target',
          );
          continue;
        }
        final asFile = File(resolved);
        final asDir = Directory(resolved);
        if (!asFile.existsSync() && !asDir.existsSync()) {
          broken++;
          stderr.writeln(
            '${_rel(root, file.path)}:${link.line}: missing path -> $target',
          );
          continue;
        }
      }

      if (fragment.isEmpty) continue;
      if (!resolved.endsWith('.md')) continue;

      final anchors = anchorCache.putIfAbsent(
        resolved,
        () => _anchorsOf(File(resolved).readAsStringSync()),
      );
      if (!anchors.contains(_decode(fragment).toLowerCase())) {
        broken++;
        stderr.writeln(
          '${_rel(root, file.path)}:${link.line}: missing anchor -> $target',
        );
      }
    }
  }

  stdout.writeln(
    'links: checked $checked relative link(s) in ${files.length} file(s); '
    '$broken broken',
  );
  return broken;
}

/// Root-level markdown files whose links are checked.
const List<String> _linkScanRootFiles = [
  'README.md',
  'CONTRIBUTING.md',
  'CHANGELOG.md',
];

/// Directories whose markdown, at any depth, has its links checked.
const List<String> _linkScanDirs = [
  'docs',
  'test',
  'scripts',
  'tool',
  'bricks',
  'examples',
  'integration_test',
  'fastlane',
];

List<File> _linkScanFiles(Directory root) {
  final files = <File>[
    for (final name in _linkScanRootFiles) File('${root.path}/$name'),
  ].where((f) => f.existsSync()).toList();
  for (final name in _linkScanDirs) {
    final dir = Directory('${root.path}/$name');
    if (!dir.existsSync()) continue;
    files.addAll(
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md')),
    );
  }
  return files..sort((a, b) => a.path.compareTo(b.path));
}

class _Link {
  const _Link(this.target, this.line);
  final String target;
  final int line;
}

/// Inline markdown links `[text](target)`, with the 1-based source line.
///
/// Titles (`[t](url "title")`) and angle-bracketed targets are handled; image
/// links are included because a broken image path is just as broken.
Iterable<_Link> _inlineLinks(String body) sync* {
  final pattern = RegExp(
    r'\[[^\]\n]*\]\(([^()\s]*(?:\([^()]*\))?[^()\s]*)'
    r'(?:\s+"[^"]*")?\)',
  );
  for (final match in pattern.allMatches(body)) {
    var target = match.group(1)!.trim();
    if (target.startsWith('<') && target.endsWith('>')) {
      target = target.substring(1, target.length - 1);
    }
    final line = '\n'.allMatches(body.substring(0, match.start)).length + 1;
    yield _Link(target, line);
  }
}

bool _isExternal(String target) {
  final lower = target.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('tel:') ||
      lower.startsWith('ftp://');
}

/// Replaces fenced and indented-in-fence code with blank lines so link and
/// heading scanning never sees sample code. Line numbering is preserved.
String _stripCodeBlocks(String source, {bool stripInline = true}) {
  final out = StringBuffer();
  var inFence = false;
  String? fenceMarker;
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    final fence = RegExp('^(`{3,}|~{3,})').firstMatch(trimmed);
    if (fence != null) {
      final marker = fence.group(1)![0];
      if (!inFence) {
        inFence = true;
        fenceMarker = marker;
      } else if (marker == fenceMarker) {
        inFence = false;
        fenceMarker = null;
      }
      out.writeln();
      continue;
    }
    out.writeln(inFence ? '' : (stripInline ? _stripInlineCode(line) : line));
  }
  return out.toString();
}

String _stripInlineCode(String line) =>
    line.replaceAll(RegExp('`[^`]*`'), '``');

/// GitHub's heading slugs: lowercase, drop everything that is not a letter,
/// digit, space, hyphen or underscore, then spaces become hyphens. Duplicates
/// get a `-1`, `-2` suffix.
Set<String> _anchorsOf(String source) {
  final anchors = <String>{};
  final seen = <String, int>{};
  final body = _stripCodeBlocks(source, stripInline: false);
  for (final line in body.split('\n')) {
    final match = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$').firstMatch(line);
    if (match == null) continue;
    final slug = _slug(_plainText(match.group(2)!));
    if (slug.isEmpty) continue;
    final count = seen.update(slug, (v) => v + 1, ifAbsent: () => 0);
    anchors.add(count == 0 ? slug : '$slug-$count');
  }
  return anchors;
}

/// Strips the inline markdown a renderer would not put in the anchor text.
///
/// `_` is deliberately kept: CommonMark does not treat an intra-word
/// underscore as emphasis, so `## Routing: go_router` anchors as
/// `routing-go_router`, not `routing-gorouter`.
String _plainText(String heading) => heading
    .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
    .replaceAll('`', '')
    .replaceAll(RegExp('[*~]'), '')
    .trim();

String _slug(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch) ||
        ch == '-' ||
        ch == '_') {
      buffer.write(ch);
    } else if (ch == ' ') {
      buffer.write('-');
    }
  }
  return buffer.toString();
}

// ===========================================================================
// Emoji
// ===========================================================================

/// Code point ranges treated as emoji. Deliberately narrow: box-drawing
/// characters, arrows, dashes and typographic quotes are text, not emoji, and
/// the repository uses them in diagrams and prose.
const List<List<int>> _emojiRanges = [
  [0x1F000, 0x1FAFF], // pictographs, transport, symbols, supplements
  [0x1F1E6, 0x1F1FF], // regional indicators (flags)
  [0x2600, 0x27BF], // misc symbols and dingbats (includes check marks)
  [0x2B00, 0x2BFF], // misc symbols and arrows (thick/emoji arrows)
  [0xFE0F, 0xFE0F], // variation selector-16 (emoji presentation)
  [0x20E3, 0x20E3], // combining enclosing keycap
  [0x2049, 0x2049], // exclamation question mark
  [0x203C, 0x203C], // double exclamation mark
  [0x2122, 0x2122], // trade mark sign
  [0x2139, 0x2139], // information source
  [0x3030, 0x3030],
  [0x303D, 0x303D],
  [0x3297, 0x3299],
];

bool _isEmoji(int rune) {
  for (final range in _emojiRanges) {
    if (rune >= range[0] && rune <= range[1]) return true;
  }
  return false;
}

int _checkEmoji(Directory root) {
  final targets = <File>[
    ...?_maybeFile('${root.path}/CLAUDE.md'),
    ..._markdownUnder('${root.path}/docs'),
    ..._markdownUnder('${root.path}/.claude'),
  ]..sort((a, b) => a.path.compareTo(b.path));

  var hits = 0;
  for (final file in targets) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final found = lines[i].runes.where(_isEmoji).toList();
      if (found.isEmpty) continue;
      hits++;
      final chars = found
          .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
          .join(' ');
      stderr.writeln('${_rel(root, file.path)}:${i + 1}: emoji ($chars)');
    }
  }
  stdout.writeln(
    'emoji: scanned ${targets.length} file(s); $hits line(s) with emoji',
  );
  return hits;
}

List<File>? _maybeFile(String path) {
  final file = File(path);
  return file.existsSync() ? [file] : null;
}

List<File> _markdownUnder(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList();
}

// ===========================================================================
// Path helpers
// ===========================================================================

String _dirname(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '.' : path.substring(0, i);
}

String _normalize(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (parts.isNotEmpty && parts.last != '..') {
        parts.removeLast();
      } else {
        parts.add('..');
      }
      continue;
    }
    parts.add(segment);
  }
  return (path.startsWith('/') ? '/' : '') + parts.join('/');
}

String _rel(Directory root, String path) => path.startsWith('${root.path}/')
    ? path.substring(root.path.length + 1)
    : path;

/// Percent-decodes a link target, leaving anything malformed untouched.
///
/// Checked rather than caught: `Uri.decodeComponent` throws `ArgumentError`,
/// and catching an `Error` is a lint here (and the wrong shape - a malformed
/// link is data, not a programming mistake).
String _decode(String value) {
  if (!value.contains('%')) return value;
  final wellFormed = RegExp(r'^(?:[^%]|%[0-9a-fA-F]{2})*$');
  if (!wellFormed.hasMatch(value)) return value;
  return Uri.decodeComponent(value);
}
