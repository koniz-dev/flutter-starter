// Constructor-signature drift checker for documentation.
//
// Prose drifts from code silently. `docs/api/core/network.md` documented an
// `AuthInterceptor` parameter that never existed while omitting three that
// did, across four separate commits, because nothing compared the two
// (koniz-dev/flutter-starter#89).
//
// A documentation block opts into checking with an HTML comment directly
// above its fenced code block:
//
//     <!-- signature: lib/core/network/api_client.dart ApiClient -->
//     ```dart
//     ApiClient({
//       required StorageService storageService,
//       ...
//     });
//     ```
//
// The named-parameter list inside the documented `ApiClient({ ... })` must
// then match the one in the constructor of the same name in that source file,
// parameter for parameter, in order, including types, `required` markers and
// default values. Comments and surrounding prose are ignored, so a block may
// keep its `///` explanation.
//
// Deliberately textual rather than semantic: it catches a parameter that was
// *added* to the source and never documented, which is the drift that actually
// happened and which no compile-time check can see (an extra optional named
// parameter breaks nothing that already compiles).
//
// Run by `tool/check_docs.dart` (Docs check, which fires on markdown) and by
// `test/docs/doc_signatures_test.dart` (Quality gate, which fires on `lib/`).
// Neither trigger alone covers both sides of the drift.

import 'dart:io';

/// One `<!-- signature: ... -->` directive found in a markdown file.
class SignatureDirective {
  /// Creates a directive record.
  const SignatureDirective({
    required this.docFile,
    required this.line,
    required this.sourcePath,
    required this.className,
  });

  /// Markdown file the directive was found in.
  final String docFile;

  /// 1-based line of the directive itself.
  final int line;

  /// Repository-relative path of the Dart source to compare against.
  final String sourcePath;

  /// Constructor name to look for in both files.
  final String className;
}

/// A problem found while checking one directive.
class SignatureProblem {
  /// Creates a problem record.
  const SignatureProblem(this.location, this.message);

  /// `file:line` the problem should be reported against.
  final String location;

  /// Human-readable description.
  final String message;

  @override
  String toString() => '$location: $message';
}

/// Directive syntax: `<!-- signature: <source path> <ConstructorName> -->`.
final RegExp _directivePattern = RegExp(
  r'^\s*<!--\s*signature:\s*(\S+)\s+([A-Za-z_][A-Za-z0-9_.]*)\s*-->\s*$',
);

final RegExp _fencePattern = RegExp(r'^\s*(`{3,}|~{3,})');

/// Checks every signature directive under [root], printing results.
///
/// Returns the number of problems found; 0 means clean.
int checkSignatures(Directory root, {bool verbose = true}) {
  final problems = <SignatureProblem>[];
  final directives = <SignatureDirective>[];

  final docsDir = Directory('${root.path}/docs');
  if (!docsDir.existsSync()) {
    stderr.writeln('docs/ not found; run from the repository root.');
    return 1;
  }

  final files =
      docsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .where((f) => !f.path.contains('docs/verification/'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final relative = _rel(root, file.path);
    final lines = file.readAsLinesSync();
    // Directives written *inside* a fenced block are documentation about the
    // directive syntax itself, not directives. Track fences and skip them.
    String? openFence;
    for (var i = 0; i < lines.length; i++) {
      final fence = _fencePattern.firstMatch(lines[i]);
      if (fence != null) {
        final marker = fence.group(1)![0];
        if (openFence == null) {
          openFence = marker;
        } else if (openFence == marker) {
          openFence = null;
        }
        continue;
      }
      if (openFence != null) continue;

      final match = _directivePattern.firstMatch(lines[i]);
      if (match == null) continue;
      final directive = SignatureDirective(
        docFile: relative,
        line: i + 1,
        sourcePath: match.group(1)!,
        className: match.group(2)!,
      );
      directives.add(directive);
      problems.addAll(_checkOne(root, directive, lines, i));
    }
  }

  if (verbose) {
    for (final problem in problems) {
      stderr.writeln(problem.toString());
    }
    stdout.writeln(
      'signatures: checked ${directives.length} documented constructor(s); '
      '${problems.length} mismatched',
    );
  }
  return problems.length;
}

List<SignatureProblem> _checkOne(
  Directory root,
  SignatureDirective directive,
  List<String> lines,
  int directiveIndex,
) {
  final location = '${directive.docFile}:${directive.line}';

  final block = _fencedBlockAfter(lines, directiveIndex);
  if (block == null) {
    return [
      SignatureProblem(
        location,
        'signature directive is not followed by a fenced code block',
      ),
    ];
  }

  final source = File('${root.path}/${directive.sourcePath}');
  if (!source.existsSync()) {
    return [
      SignatureProblem(
        location,
        'source file not found -> ${directive.sourcePath}',
      ),
    ];
  }

  final documented = namedParameters(block, directive.className);
  if (documented == null) {
    return [
      SignatureProblem(
        location,
        'the fenced block has no `${directive.className}({` declaration '
        'opening a named-parameter list',
      ),
    ];
  }

  final actual = namedParameters(
    source.readAsStringSync(),
    directive.className,
  );
  if (actual == null) {
    return [
      SignatureProblem(
        location,
        'no `${directive.className}({` constructor found in '
        '${directive.sourcePath}',
      ),
    ];
  }

  if (_listEquals(documented, actual)) {
    return const [];
  }

  final problems = <SignatureProblem>[
    SignatureProblem(
      location,
      '${directive.className} does not match ${directive.sourcePath}',
    ),
  ];
  final max = documented.length > actual.length
      ? documented.length
      : actual.length;
  for (var i = 0; i < max; i++) {
    final doc = i < documented.length ? documented[i] : '(missing)';
    final src = i < actual.length ? actual[i] : '(not in source)';
    if (doc == src) continue;
    problems.add(
      SignatureProblem(
        location,
        '  param ${i + 1}: doc `$doc` vs source `$src`',
      ),
    );
  }
  return problems;
}

/// Returns the contents of the first fenced code block at or after
/// [directiveIndex], or null when the next non-blank line is not a fence.
String? _fencedBlockAfter(List<String> lines, int directiveIndex) {
  var i = directiveIndex + 1;
  while (i < lines.length && lines[i].trim().isEmpty) {
    i++;
  }
  if (i >= lines.length) return null;
  final open = _fencePattern.firstMatch(lines[i]);
  if (open == null) return null;
  final marker = open.group(1)![0];

  final body = StringBuffer();
  for (var j = i + 1; j < lines.length; j++) {
    final close = _fencePattern.firstMatch(lines[j]);
    if (close != null && close.group(1)![0] == marker) {
      return body.toString();
    }
    body.writeln(lines[j]);
  }
  return null;
}

/// Extracts the named parameters of `name({ ... })` from [text].
///
/// Returns one normalized entry per parameter (whitespace collapsed, trailing
/// comma dropped, comments removed), or null when no such declaration exists.
///
/// The declaration must open with `name({` at the end of a line and close with
/// a line starting `})`, which is what `dart format` produces for every
/// multi-line named-parameter constructor in this repository. A one-line
/// constructor is not matched on purpose: it would be reported as missing
/// rather than silently passing.
List<String>? namedParameters(String text, String name) {
  const prefixes = ['', 'const ', 'factory '];
  final openings = prefixes.map((p) => '$p$name({').toSet();
  final lines = text.split('\n');

  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (openings.contains(lines[i].trim())) {
      start = i + 1;
      break;
    }
  }
  if (start < 0) return null;

  final buffer = StringBuffer();
  var closed = false;
  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    if (RegExp(r'^\s*\}\)').hasMatch(line)) {
      closed = true;
      break;
    }
    buffer
      ..write(_stripLineComment(line))
      ..write(' ');
  }
  if (!closed) return null;

  return _splitTopLevel(buffer.toString())
      .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

String _stripLineComment(String line) {
  final index = line.indexOf('//');
  return index < 0 ? line : line.substring(0, index);
}

/// Splits on commas that are not nested inside `()`, `[]`, `{}` or `<>`.
List<String> _splitTopLevel(String text) {
  final parts = <String>[];
  final current = StringBuffer();
  var depth = 0;
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '(' || ch == '[' || ch == '{' || ch == '<') depth++;
    if (ch == ')' || ch == ']' || ch == '}' || ch == '>') depth--;
    if (ch == ',' && depth == 0) {
      parts.add(current.toString());
      current.clear();
      continue;
    }
    current.write(ch);
  }
  parts.add(current.toString());
  return parts;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _rel(Directory root, String path) => path.startsWith('${root.path}/')
    ? path.substring(root.path.length + 1)
    : path;
