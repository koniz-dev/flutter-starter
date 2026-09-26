// Existence checker for Dart identifiers named in documentation.
//
// `docs/architecture/contracts-map.md` is the document an adopter follows to
// swap an implementation, and it cited `tasksControllerProvider` and
// `FirebaseFeatureFlagsRemoteDataSource` - two identifiers that have never
// existed anywhere in this repository. Nothing caught it
// (koniz-dev/flutter-starter#182, split out as #206).
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

/// Directive syntax: `<!-- symbol: <source path> <identifier> -->`.
final RegExp _directivePattern = RegExp(
  r'^\s*<!--\s*symbol:\s*(\S+)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*-->\s*$',
);

final RegExp _fencePattern = RegExp(r'^\s*(`{3,}|~{3,})');

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
          .where((f) => !f.path.contains('docs/verification/'))
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
      if (match == null) continue;

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
      if (!declaresSymbol(source.readAsStringSync(), directive.symbol)) {
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
bool declaresSymbol(String source, String name) {
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
  return patterns.any((p) => p.hasMatch(source));
}

String _rel(Directory root, String path) => path.startsWith('${root.path}/')
    ? path.substring(root.path.length + 1)
    : path;
