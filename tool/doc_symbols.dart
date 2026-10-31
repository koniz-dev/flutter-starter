// Existence checker for Dart identifiers named in documentation.
//
// `docs/architecture/contracts-map.md` is the document an adopter follows to
// swap an implementation, and it cited `tasksControllerProvider` and
// `FirebaseFeatureFlagsRemoteDataSource` - two identifiers that have never
// existed anywhere in this repository. Nothing caught it.
//
// `tool/doc_signatures.dart` already checks the strong assertion - *this
// constructor's parameter list matches* - but it only fits a documented
// signature block. This file checks the weak, broad one:
//
//     <!-- symbol: lib/core/di/providers.dart apiClientProvider -->
//
// "the identifier `apiClientProvider` is declared in that file". No fenced
// block, no position, nothing about the shape of the declaration.
//
// Explicit directives rather than scanning inline code spans, deliberately.
// The swap map's cells mix identifiers, paths and prose, so a heuristic would
// either miss the phantom or drown the author in false positives. One
// directive per asserted symbol is verbose and exact, which is the right trade
// for a document whose whole job is being exact.
//
// Run by `tool/check_docs.dart` (Docs check, which fires on markdown) and by
// `test/docs/doc_symbols_test.dart` (Quality gate, which fires on `lib/`).
// Neither trigger alone covers both sides: the first catches a symbol mistyped
// in a document, the second catches one deleted from `lib/`.

import 'dart:io';

/// One `<!-- symbol: ... -->` directive found in a markdown file.
class SymbolDirective {
  /// Creates a directive record.
  const SymbolDirective({
    required this.docFile,
    required this.line,
    required this.sourcePath,
    required this.symbol,
  });

  /// Markdown file the directive was found in.
  final String docFile;

  /// 1-based line of the directive itself.
  final int line;

  /// Repository-relative path of the Dart source that must declare [symbol].
  final String sourcePath;

  /// Identifier that must be declared in [sourcePath].
  final String symbol;
}

/// A problem found while checking one directive.
class SymbolProblem {
  /// Creates a problem record.
  const SymbolProblem(this.location, this.message);

  /// `file:line` the problem should be reported against.
  final String location;

  /// Human-readable description.
  final String message;

  @override
  String toString() => '$location: $message';
}

/// Directive syntax: `<!-- symbol: <source path> <identifier> -->`, where
/// the identifier is a top-level name or `Type.member`.
final RegExp _directivePattern = RegExp(
  r'^\s*<!--\s*symbol:\s*(\S+)\s+'
  r'([A-Za-z_$][A-Za-z0-9_$]*(?:\.[A-Za-z_$][A-Za-z0-9_$]*)?)\s*-->\s*$',
);

final RegExp _fencePattern = RegExp(r'^\s*(`{3,}|~{3,})');

/// A line that opens a symbol directive, outside inline code. One that does
/// not then match [_directivePattern] in full - a missing identifier, a third
/// word, text after `-->` - used to be skipped without a word, so the symbol
/// it named went unchecked.
bool _looksLikeDirective(String line) =>
    line.replaceAll(RegExp('`[^`]*`'), '').contains(RegExp(r'<!--\s*symbol:'));

/// Outcome of a scan: what was asserted, and what did not hold.
class SymbolCheckResult {
  /// Creates a result record.
  const SymbolCheckResult(this.directives, this.problems);

  /// Every directive found, whether or not it resolved.
  final List<SymbolDirective> directives;

  /// One entry per directive that did not resolve.
  final List<SymbolProblem> problems;
}

/// Checks every symbol directive under [root], printing results.
///
/// Returns the number of problems found; 0 means clean.
int checkSymbols(Directory root, {bool verbose = true}) {
  final result = collectSymbolProblems(root);
  if (verbose) {
    for (final problem in result.problems) {
      stderr.writeln(problem.toString());
    }
    stdout.writeln(
      'symbols: checked ${result.directives.length} directive(s); '
      '${result.problems.length} unresolved',
    );
  }
  return result.problems.length;
}

/// Scans every markdown file under `[root]/docs` and resolves its directives.
///
/// Separate from [checkSymbols] so a test can assert on the messages rather
/// than only on the count - a checker that fails without saying which
/// directive, in which file, on which line, costs more than it saves.
SymbolCheckResult collectSymbolProblems(Directory root) {
  final problems = <SymbolProblem>[];
  final directives = <SymbolDirective>[];

  final docsDir = Directory('${root.path}/docs');
  if (!docsDir.existsSync()) {
    return SymbolCheckResult(directives, [
      const SymbolProblem(
        'docs/',
        'not found; run from the repository root',
      ),
    ]);
  }

  final files =
      docsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          // Evidence directories are frozen records of a past run. A directive
          // in one would start failing the day the code it described changed,
          // which is the opposite of what an evidence file is for.
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final relative = _rel(root, file.path);
    final lines = file.readAsLinesSync();
    // A directive written inside a fenced block is documentation about the
    // syntax, not a directive.
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
      if (match == null) {
        if (_looksLikeDirective(lines[i])) {
          problems.add(
            SymbolProblem(
              '$relative:${i + 1}',
              'malformed directive; expected '
                  '`<!-- symbol: <source path> <identifier> -->` alone on '
                  'its line',
            ),
          );
        }
        continue;
      }

      final directive = SymbolDirective(
        docFile: relative,
        line: i + 1,
        sourcePath: match.group(1)!,
        symbol: match.group(2)!,
      );
      directives.add(directive);

      final location = '${directive.docFile}:${directive.line}';
      final source = File('${root.path}/${directive.sourcePath}');
      if (!source.existsSync()) {
        problems.add(
          SymbolProblem(
            location,
            'source file not found -> ${directive.sourcePath} '
            '(directive names `${directive.symbol}`)',
          ),
        );
        continue;
      }
      if (!_resolves(source.readAsStringSync(), directive.symbol)) {
        problems.add(
          SymbolProblem(
            location,
            '`${directive.symbol}` is not declared in '
            '${directive.sourcePath}',
          ),
        );
      }
    }
  }

  return SymbolCheckResult(directives, problems);
}

/// Whether [source] declares [symbol]: a top-level name, or `Type.member`.
bool _resolves(String source, String symbol) {
  final dot = symbol.indexOf('.');
  if (dot < 0) return declaresSymbol(source, symbol);
  return declaresMember(
    source,
    symbol.substring(0, dot),
    symbol.substring(dot + 1),
  );
}

/// Whether the class, mixin, enum or extension [type] in [source] declares
/// [member] directly: a named or factory constructor (`Type.member(`), a
/// method, a getter or setter, or a field.
///
/// Only the type's own body is searched, and only at its top level - a call
/// such as `return toJson();` inside a method body is not a declaration.
/// Inherited and mixed-in members do not count: the directive asserts where
/// the member is written. Textual like [declaresSymbol], and for the same
/// reason.
bool declaresMember(String source, String type, String member) {
  final t = RegExp.escape(type);
  final header = RegExp(
    r'^\s*(?:abstract\s+|base\s+|interface\s+|final\s+|sealed\s+|mixin\s+)*'
    '(?:class|mixin|enum|extension(?:\\s+type)?)\\s+$t'
    r'\b[^{]*\{',
    multiLine: true,
  ).firstMatch(source);
  if (header == null) return false;

  // The body, from after the opening brace to its matching close. Strings
  // and comments are skipped so a brace inside one does not count.
  final bodyStart = header.end;
  var depth = 1;
  var i = bodyStart;
  final topLevel = StringBuffer();
  while (i < source.length && depth > 0) {
    final c = source[i];
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final quote = source.startsWith(c * 3, i) ? c * 3 : c;
      // `r'...'`: a backslash is an ordinary character, so `r'\'` closes
      // on its second quote. Reading it as an escape ran on through the rest
      // of the body and hid every declaration after it.
      final raw =
          i > 0 &&
          source[i - 1] == 'r' &&
          (i < 2 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(source[i - 2]));
      var j = i + quote.length;
      while (j < source.length && !source.startsWith(quote, j)) {
        j += !raw && source[j] == r'\' ? 2 : 1;
      }
      i = j + quote.length;
      if (depth == 1) topLevel.write('""');
      continue;
    }
    if (c == '{' || c == '(' || c == '[') depth++;
    if (c == '}' || c == ')' || c == ']') depth--;
    // Keep only what sits directly in the body; a nested block contributes
    // its opening bracket, so `name(` and `name {` still read as declared.
    if (depth == 1 || (depth == 2 && (c == '(' || c == '{' || c == '['))) {
      topLevel.write(c);
    } else if (c == '\n') {
      topLevel.write('\n');
    }
    i++;
  }

  final m = RegExp.escape(member);
  // What follows `=` or `=>`, up to the next `;`, `,`, `{` or `}`, is an
  // initializer or an expression body, not a declaration:
  // `final int y = helper(2);` names `helper` without declaring it. Stopping
  // at a brace keeps a constructor's `: _dio = _createDio(...) {}` from
  // swallowing the declarations after it, and at a comma the next declarator
  // in `int z = 0, w = 1;` (nested brackets are already gone from the body,
  // so a comma here separates declarators). An operator such as `==` or `<=`
  // loses only its own text, which never names a member.
  final body = topLevel.toString().replaceAll(
    RegExp('=>?[^;,{}]*'),
    '',
  );
  return [
    // Named or factory constructor: `Type.member(`.
    RegExp('\\b$t\\.$m\\s*\\('),
    // Method, getter, setter or field, at the body's top level.
    RegExp(
      r'(?:^|[;}\s])(?:get\s+|set\s+)?'
      '$m'
      r'\s*(?:<[^>]*>\s*)?(?:\(|=|;|=>|\{|,)',
      multiLine: true,
    ),
  ].any((p) => p.hasMatch(body));
}

/// Whether [source] declares a top-level or type-level [name].
///
/// Accepts the declaration forms this repository actually uses: `class` in all
/// its modifier spellings, `mixin`, `enum`, `extension`, `extension type`,
/// `typedef`, a top-level `final`/`const`/`late`/`var` variable, and a
/// top-level function.
///
/// Generated output counts. `featureFlagsRemoteDataSourceProvider` exists only
/// in a `.g.dart`, so restricting this to hand-written files would make the
/// most drift-prone identifiers in the repository the ones it cannot check.
///
/// Textual, not semantic - the analyzer is not available to a script that has
/// to run before `flutter pub get`. The patterns are anchored at the start of
/// a line, which is what keeps a mention inside a `//` or `///` comment from
/// counting: a comment line begins with the slashes, not with `class` or
/// `final`.
///
/// Block comments and string literals are blanked first, newlines kept, so
/// `class Ghost {}` inside `/* */` or a `'''` string is not a declaration.
bool declaresSymbol(String source, String name) {
  final code = _blankCommentsAndStrings(source);
  final n = RegExp.escape(name);
  final patterns = <RegExp>[
    // abstract / base / interface / final / sealed / mixin class
    RegExp(
      r'^\s*(?:abstract\s+|base\s+|interface\s+|final\s+|sealed\s+|mixin\s+)*'
      'class\\s+$n'
      r'\b',
      multiLine: true,
    ),
    RegExp(
      r'^\s*(?:base\s+)?mixin\s+'
      '$n'
      r'\b',
      multiLine: true,
    ),
    RegExp(
      r'^\s*enum\s+'
      '$n'
      r'\b',
      multiLine: true,
    ),
    RegExp(
      r'^\s*extension\s+(?:type\s+(?:const\s+)?)?'
      '$n'
      r'\b',
      multiLine: true,
    ),
    RegExp(
      r'^\s*typedef\s+'
      '$n'
      r'\b',
      multiLine: true,
    ),
    // Top-level variable, with or without an explicit type:
    //   final apiClientProvider = ...        const goRouterProvider = ...
    //   final Provider<ApiClient> apiClientProvider = ...
    RegExp(
      r'^(?:final|const|late|var)\b[^=;(){}]*\b'
      '$n'
      r'\s*(?:=|;)',
      multiLine: true,
    ),
    // Top-level function, at column 0 because that is where a top-level
    // declaration sits in formatted Dart:
    //   GoRouter goRouter(Ref ref) {        void main() {
    RegExp(
      r'^[A-Za-z_$][A-Za-z0-9_$<>,\s?\[\].]*\s'
      '$n'
      r'\s*(?:<[^>]*>)?\s*\(',
      multiLine: true,
    ),
    RegExp(
      '^$n'
      r'\s*(?:<[^>]*>)?\s*\(',
      multiLine: true,
    ),
  ];
  return patterns.any((p) => p.hasMatch(code));
}

/// [source] with every block comment and string literal replaced by spaces,
/// newlines kept so line-anchored patterns still see the same lines. `//`
/// comments are left alone: the patterns are anchored, and a comment line
/// starts with its slashes.
String _blankCommentsAndStrings(String source) {
  final out = StringBuffer();
  String blank(String text) => text.replaceAll(RegExp('[^\n]'), ' ');
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      final stop = end < 0 ? source.length : end;
      out.write(source.substring(i, stop));
      i = stop;
      continue;
    }
    if (source.startsWith('/*', i)) {
      // Dart block comments nest.
      var depth = 0;
      var j = i;
      while (j < source.length) {
        if (source.startsWith('/*', j)) {
          depth++;
          j += 2;
        } else if (source.startsWith('*/', j)) {
          depth--;
          j += 2;
          if (depth == 0) break;
        } else {
          j++;
        }
      }
      out.write(blank(source.substring(i, j)));
      i = j;
      continue;
    }
    if (c == "'" || c == '"') {
      final quote = source.startsWith(c * 3, i) ? c * 3 : c;
      final raw =
          i > 0 &&
          source[i - 1] == 'r' &&
          (i < 2 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(source[i - 2]));
      var j = i + quote.length;
      while (j < source.length && !source.startsWith(quote, j)) {
        j += !raw && source[j] == r'\' ? 2 : 1;
      }
      final end = j + quote.length > source.length
          ? source.length
          : j + quote.length;
      out.write(blank(source.substring(i, end)));
      i = end;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

String _rel(Directory root, String path) => path.startsWith('${root.path}/')
    ? path.substring(root.path.length + 1)
    : path;
