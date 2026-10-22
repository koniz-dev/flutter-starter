// Constructor-signature drift checker for documentation.
//
// Prose drifts from code silently. `docs/api/core/network.md` documented an
// `AuthInterceptor` parameter that never existed while omitting three that
// did, across four separate commits, because nothing compared the two.
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
// The parameter list of the documented `ApiClient(...)` must then match the
// one in the constructor of the same name in that source file, parameter for
// parameter, in order. Positional, optional-positional (`[...]`) and named
// (`{...}`) parameters are all compared, and the declaration may sit on one
// line or many. Comments and surrounding prose are ignored, so a block may
// keep its `///` explanation.
//
// Two parameters match when:
//
//   * neither is a super- or field-formal (`super.code`, `this.statusCode`):
//     their texts are equal - type, `required` marker and default value;
//   * either one is: they are of the same kind and have the same name, the
//     same `required` marker and the same default value. Types are not
//     compared. Docs write the reader-facing type (`String? code`) where the
//     source says `super.code`, and resolving the type behind a formal would
//     need the analyzer; the name and optionality are what a caller copies.
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

  final documented = parameters(block, directive.className);
  if (documented == null) {
    return [
      SignatureProblem(
        location,
        'the fenced block has no `${directive.className}(` declaration',
      ),
    ];
  }

  final actual = parameters(source.readAsStringSync(), directive.className);
  if (actual == null) {
    return [
      SignatureProblem(
        location,
        'no `${directive.className}(` constructor found in '
        '${directive.sourcePath}',
      ),
    ];
  }

  final max = documented.length > actual.length
      ? documented.length
      : actual.length;
  final mismatches = <SignatureProblem>[];
  for (var i = 0; i < max; i++) {
    final doc = i < documented.length ? documented[i] : null;
    final src = i < actual.length ? actual[i] : null;
    if (doc != null && src != null && doc.matches(src)) continue;
    mismatches.add(
      SignatureProblem(
        location,
        '  param ${i + 1}: doc `${doc ?? '(missing)'}` vs source '
        '`${src ?? '(not in source)'}`',
      ),
    );
  }
  if (mismatches.isEmpty) return const [];
  return [
    SignatureProblem(
      location,
      '${directive.className} does not match ${directive.sourcePath}',
    ),
    ...mismatches,
  ];
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

/// How a parameter is passed.
enum ParameterKind {
  /// Required positional.
  positional,

  /// Inside `[...]`.
  optionalPositional,

  /// Inside `{...}`.
  named,
}

/// One parameter of a constructor's parameter list.
class DocParameter {
  /// Parses one parameter's [text] (whitespace already collapsed).
  factory DocParameter.parse(String text, ParameterKind kind) {
    final equals = _topLevelEquals(text);
    var head = (equals < 0 ? text : text.substring(0, equals)).trim();
    final defaultValue = equals < 0 ? null : text.substring(equals + 1).trim();
    final isRequired = head.startsWith('required ');
    if (isRequired) head = head.substring('required '.length).trim();
    final formal = RegExp(r'(?:^|\s)(?:super|this)\.(\w+)$').firstMatch(head);
    final name =
        formal?.group(1) ?? RegExp(r'(\w+)$').firstMatch(head)?.group(1);
    return DocParameter._(
      text: text,
      kind: kind,
      name: name ?? head,
      isRequired: isRequired,
      defaultValue: defaultValue,
      isFormal: formal != null,
    );
  }

  const DocParameter._({
    required this.text,
    required this.kind,
    required this.name,
    required this.isRequired,
    required this.defaultValue,
    required this.isFormal,
  });

  /// The parameter as written, whitespace collapsed.
  final String text;

  /// Positional, optional positional or named.
  final ParameterKind kind;

  /// The parameter's name, with any `super.` / `this.` dropped.
  final String name;

  /// Whether it is marked `required`.
  final bool isRequired;

  /// The default value's text, or null when it has none.
  final String? defaultValue;

  /// Whether it is a super- or field-formal (`super.code`, `this.code`).
  final bool isFormal;

  /// Whether a documented parameter and a source parameter agree, by the rule
  /// in this file's header.
  bool matches(DocParameter other) {
    if (kind != other.kind) return false;
    if (!isFormal && !other.isFormal) return text == other.text;
    return name == other.name &&
        isRequired == other.isRequired &&
        defaultValue == other.defaultValue;
  }

  @override
  String toString() => kind == ParameterKind.positional
      ? text
      : kind == ParameterKind.named
      ? '{$text}'
      : '[$text]';
}

/// Extracts the parameters of the constructor `name(...)` from [text].
///
/// The declaration is the first line that starts - after indentation, and an
/// optional `const ` or `factory ` - with `name(`; its list runs to the
/// matching `)`, on that line or any later one. Returns one entry per
/// parameter (whitespace collapsed, trailing comma dropped, comments
/// removed), or null when no such declaration exists or it never closes.
List<DocParameter>? parameters(String text, String name) {
  final opening = RegExp('^\\s*(?:const |factory )?${RegExp.escape(name)}\\(');
  final lines = text.split('\n');
  final start = lines.indexWhere(opening.hasMatch);
  if (start < 0) return null;

  final rest = [
    lines[start].substring(opening.firstMatch(lines[start])!.end),
    ...lines.skip(start + 1),
  ].map(_stripLineComment).join(' ');

  final list = _untilClose(rest);
  if (list == null) return null;

  final params = <DocParameter>[];
  void add(String part, ParameterKind kind) {
    for (final raw in _splitTopLevel(part)) {
      final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isNotEmpty) {
        params.add(DocParameter.parse(normalized, kind));
      }
    }
  }

  final group = _topLevelGroupStart(list);
  if (group < 0) {
    add(list, ParameterKind.positional);
  } else {
    add(list.substring(0, group), ParameterKind.positional);
    final inner = _untilClose(list.substring(group + 1));
    if (inner == null) return null;
    add(
      inner,
      list[group] == '{'
          ? ParameterKind.named
          : ParameterKind.optionalPositional,
    );
  }
  return params;
}

/// The text before the bracket that closes the one already open at its
/// start, or null when it never closes.
String? _untilClose(String text) {
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if ('([{<'.contains(ch)) depth++;
    if (')]}>'.contains(ch)) {
      if (depth == 0) return text.substring(0, i);
      depth--;
    }
  }
  return null;
}

/// Index of a `{` or `[` opening a named or optional group at depth 0, or -1.
int _topLevelGroupStart(String list) {
  var depth = 0;
  for (var i = 0; i < list.length; i++) {
    final ch = list[i];
    if ((ch == '{' || ch == '[') && depth == 0) return i;
    if ('([{<'.contains(ch)) depth++;
    if (')]}>'.contains(ch)) depth--;
  }
  return -1;
}

/// Index of the `=` introducing a default value, ignoring `=>`, `==`, `<=`
/// and `>=` and anything nested, or -1.
int _topLevelEquals(String text) {
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if ('([{<'.contains(ch)) depth++;
    if (')]}>'.contains(ch)) depth--;
    if (ch != '=' || depth != 0) continue;
    final next = i + 1 < text.length ? text[i + 1] : '';
    final prev = i > 0 ? text[i - 1] : '';
    if (next == '>' || next == '=' || '=!<>'.contains(prev) && prev != '') {
      continue;
    }
    return i;
  }
  return -1;
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

String _rel(Directory root, String path) => path.startsWith('${root.path}/')
    ? path.substring(root.path.length + 1)
    : path;
