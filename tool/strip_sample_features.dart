// Removes sample `tasks` and `feature_flags` feature modules and rewires
// the app using golden files under tool/golden/<variant>/.
//
// Every variant also removes this repository's own process machinery - the
// issue loop, its evidence archive and the guards that only make sense against
// this tracker. See `_processOnlyPaths` for the list and the reasoning per
// entry.
//
// Usage (from repository root):
//   dart run tool/strip_sample_features.dart --apply                       both
//   dart run tool/strip_sample_features.dart --apply --remove-tasks
//   dart run tool/strip_sample_features.dart --apply --remove-feature-flags
//
// Then:
//   flutter pub get && flutter analyze && flutter test
//
// Every variant is exercised by .github/workflows/strip-smoke.yml. Adding a
// golden file that no variant lists, or listing one that does not exist, is a
// hard error here - that is what kept the partial variants broken while CI
// only ever ran the `stripped` one.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Files each variant overwrites from `tool/golden/<variant>/`.
///
/// Only files whose post-strip content actually differs from the committed
/// tree are listed. The partial variants need far fewer overrides than
/// `stripped` because `lib/main.dart` and the home screen are already
/// feature-agnostic on the committed tree. `routes_registry.dart` is not:
/// since #56 it composes the tasks and feature-flags route modules, so every
/// variant needs its own copy.
///
/// The `test/core/routing/` files are deliberately absent: since #56 those
/// tests assert only the routes every variant keeps, and each sample feature
/// asserts its own routing in `test/features/<feature>/routing/`, which the
/// strip deletes with the feature. Three near-identical copies of a test file
/// is how the `stripped` copy of `app_router_test.dart` silently stayed on
/// the pre-#51 router.
const _goldenOverrides = <String, List<String>>{
  'stripped': [
    'lib/core/routing/app_router.dart',
    'lib/core/routing/app_router.g.dart',
    'lib/core/routing/routes_registry.dart',
    'lib/core/routing/app_routes.dart',
    'lib/core/routing/navigation_extensions.dart',
    'lib/main.dart',
    'lib/features/home/presentation/screens/home_screen.dart',
    'integration_test/app_e2e_test.dart',
    'integration_test/auth_flow_test.dart',
  ],
  'no_tasks': [
    'lib/core/routing/app_routes.dart',
    'lib/core/routing/navigation_extensions.dart',
    'lib/core/routing/routes_registry.dart',
  ],
  'no_feature_flags': [
    'lib/core/routing/app_routes.dart',
    'lib/core/routing/navigation_extensions.dart',
    'lib/core/routing/routes_registry.dart',
  ],
};

/// Paths that exist to run **this repository's** issue loop rather than to
/// serve an adopter's app. Every variant removes all of them.
///
/// The test for each entry is the one question an adopter can answer: *would
/// they notice if this were missing?* A guard that protects the shipped app
/// stays; a guard that enforces this tracker's conventions goes. Reasoning per
/// entry:
///
///   * `docs/verification/` - 31 MB of acceptance evidence about issues closed
///     in this repository. An adopter inherits an archive of work they never
///     saw, and `scripts/test/run_acceptance.sh` recreates the directory for
///     their own issues.
///   * `docs/issue-workflow.md` and `.claude/agents/` - the agent protocol and
///     the four role definitions that drive it. Process, not product.
///   * `scripts/bootstrap-issue-labels.sh` - creates this repository's labels
///     and owns its path -> epic map. A fork has neither.
///   * `tool/check_epic_coverage.dart` and `test/tooling/epic_coverage_test.dart`
///     - assert every tracked surface maps to exactly one `epic:*` label. The
///     tool shells out to the bootstrap script, so keeping the test after
///     removing that script would fail `flutter test` on the first run.
///   * `scripts/dev/check_issue_refs.sh` and `.github/workflows/issue-refs.yml`
///     - require `Refs koniz-dev/flutter-starter#N` in every commit. An
///     adopter's commits reference their own tracker, so the check would
///     reject every pull request they open.
///
/// Deliberately NOT here, because each protects the adopter's app rather than
/// this repository's workflow: `tool/check_env_assets.dart` (stops secrets
/// shipping in the bundle), `tool/doc_signatures.dart`, `tool/doc_symbols.dart`
/// and `tool/check_docs.dart` (stop docs drifting from code), `ci.yml`,
/// `strip-smoke.yml`, the git hooks, and `scripts/test/run_acceptance.sh`
/// (a format/analyze/test/golden harness that takes whatever issue number the
/// adopter's own tracker gave them).
const _processOnlyPaths = <String>[
  '.claude/agents',
  '.github/workflows/issue-refs.yml',
  'docs/issue-workflow.md',
  'docs/verification',
  'scripts/bootstrap-issue-labels.sh',
  'scripts/dev/check_issue_refs.sh',
  'test/tooling/epic_coverage_test.dart',
  'tool/check_epic_coverage.dart',
];

/// Directories to delete once emptied by [_processOnlyPaths].
const _processOnlyPrunedDirs = <String>['.claude'];

/// Markers around a block of prose that documents the removed process only.
///
/// Whole files are cheap to delete; a section inside a file an adopter keeps is
/// not, and hand-written path lists rot. These are HTML comments, so they are
/// invisible in rendered markdown and ignored by `tool/check_docs.dart`.
const _processMarkerStart = '<!-- strip:process-only start -->';
const _processMarkerEnd = '<!-- strip:process-only end -->';

/// Directory names never walked when looking for markdown.
const _markdownWalkSkips = <String>{
  '.dart_tool',
  '.git',
  '.idea',
  'build',
  'node_modules',
};

void main(List<String> args) {
  if (!args.contains('--apply')) {
    stderr.writeln(
      'Usage: dart run tool/strip_sample_features.dart --apply '
      '[--remove-tasks] [--remove-feature-flags]\n'
      'Removes lib/features/tasks, lib/features/feature_flags, related tests, '
      'and core FeatureFlagsManager. Rewires entrypoints from '
      'tool/golden/<variant>/. Keeps auth sample. Every variant also removes '
      "this repository's process-only artifacts (docs/verification/, the issue "
      'workflow, .claude/agents/ and the issue-loop guards).',
    );
    exitCode = 1;
    return;
  }

  final tasksFlag =
      args.contains('--tasks-only') || args.contains('--remove-tasks');
  final featureFlagsFlag =
      args.contains('--feature-flags-only') ||
      args.contains('--remove-feature-flags');

  // Naming both samples is the same request as naming neither: remove both.
  // This used to fall through to `removeBoth == false`, which deleted both
  // feature trees, installed the `no_tasks` golden over them and only then
  // exited 3 - an unbuildable tree with no way back short of git.
  final removeBoth = tasksFlag == featureFlagsFlag;
  final removeTasks = removeBoth || tasksFlag;
  final removeFeatureFlags = removeBoth || featureFlagsFlag;

  final root = Directory.current;
  final scriptDir = File.fromUri(Platform.script).parent;
  final goldenVariant = removeBoth
      ? 'stripped'
      : tasksFlag
      ? 'no_tasks'
      : 'no_feature_flags';
  final goldenRoot = Directory(p.join(scriptDir.path, 'golden', goldenVariant));
  if (!goldenRoot.existsSync()) {
    stderr.writeln('Missing golden directory: ${goldenRoot.path}');
    exitCode = 2;
    return;
  }

  // Validate the golden tree before deleting anything, so a bad golden set
  // leaves the working tree untouched.
  final overrides = _goldenOverrides[goldenVariant]!;
  final goldenProblems = _validateGoldenTree(goldenRoot, overrides);
  if (goldenProblems.isNotEmpty) {
    stderr.writeln(
      'Golden tree for variant "$goldenVariant" is inconsistent; '
      'nothing was deleted:\n${goldenProblems.join('\n')}',
    );
    exitCode = 2;
    return;
  }

  // Same discipline as the golden tree: an unbalanced marker pair is found
  // before anything is deleted, so a bad edit leaves the working tree intact.
  final markerProblems = _validateProcessMarkers(root);
  if (markerProblems.isNotEmpty) {
    stderr.writeln(
      'Process-only markers are unbalanced; nothing was deleted:\n'
      '${markerProblems.join('\n')}',
    );
    exitCode = 2;
    return;
  }

  // Process artifacts go first: `docs/verification/` is by far the largest
  // thing removed, and deleting it up front means the later passes over
  // `docs/` have thousands of evidence files fewer to read.
  _removeProcessArtifacts(root);
  _stripProcessMarkdownRegions(root);

  if (removeTasks) {
    _deleteDir(Directory(p.join(root.path, 'lib/features/tasks')));
    _deleteDir(Directory(p.join(root.path, 'test/features/tasks')));
  }
  if (removeFeatureFlags) {
    _deleteDir(Directory(p.join(root.path, 'lib/features/feature_flags')));
    _deleteDir(Directory(p.join(root.path, 'test/features/feature_flags')));
    _deleteDir(Directory(p.join(root.path, 'test/core/feature_flags')));
  }

  if (removeFeatureFlags) {
    final manager = File(
      p.join(root.path, 'lib/core/feature_flags/feature_flags_manager.dart'),
    );
    if (manager.existsSync()) {
      manager.deleteSync();
    }
    final ffDir = Directory(p.join(root.path, 'lib/core/feature_flags'));
    if (ffDir.existsSync() && ffDir.listSync().isEmpty) {
      ffDir.deleteSync();
    }
  }

  if (removeTasks) {
    final f = File(p.join(root.path, 'docs/features/tasks.md'));
    if (f.existsSync()) {
      f.deleteSync();
    }
  }
  if (removeFeatureFlags) {
    final f = File(p.join(root.path, 'docs/features/feature-flags.md'));
    if (f.existsSync()) {
      f.deleteSync();
    }
  }

  final goldenPath = goldenRoot.path;
  for (final relative in overrides) {
    _copyGoldenFile(goldenPath, root.path, relative);
  }

  // `lib/core/di/providers.dart` needs no patching: it names no feature at
  // all since koniz-dev/flutter-starter#221 removed the three
  // backward-compatibility re-exports this step used to strip.
  if (removeTasks) {
    _patchTestFixtures(p.join(root.path, 'test/helpers/test_fixtures.dart'));
    _patchMockFactories(p.join(root.path, 'test/helpers/mock_factories.dart'));
    _patchProvidersTest(p.join(root.path, 'test/core/di/providers_test.dart'));
  }

  final needles = <String>[
    if (removeTasks) 'package:flutter_starter/features/tasks/',
    if (removeFeatureFlags) 'package:flutter_starter/features/feature_flags/',
    if (removeFeatureFlags)
      'package:flutter_starter/core/feature_flags/feature_flags_manager.dart',
  ];

  _deleteDocsProbes(root, needles);

  // Documentation asserts identifiers with
  // `<!-- symbol: <path> <name> -->` (koniz-dev/flutter-starter#206), and
  // `test/docs/doc_symbols_test.dart` fails the run when one does not resolve.
  // A directive naming a file this strip just deleted would therefore turn
  // every stripped variant red in `flutter test`, so the directives go with
  // the files.
  _deleteSymbolDirectives(root, [
    if (removeTasks) 'lib/features/tasks/',
    if (removeFeatureFlags) 'lib/features/feature_flags/',
    if (removeFeatureFlags) 'lib/core/feature_flags/',
  ]);

  final violations = _collectStrippedViolations(root, needles);
  if (violations.isNotEmpty) {
    stderr.writeln(
      'Strip finished but forbidden references remain in code the analyzer '
      'reads:\n'
      '${violations.join('\n')}\n'
      'Fix imports or excludes before committing.',
    );
    exitCode = 3;
    return;
  }

  stdout.writeln(
    'Strip complete. Run: flutter pub get && flutter analyze && flutter test',
  );
}

/// Checks that `tool/golden/<variant>/` holds exactly the declared overrides.
///
/// A declared file that is absent would crash mid-strip; a file on disk that
/// no variant declares is never copied, so it rots silently - which is how
/// `no_tasks` and `no_feature_flags` came to import a routing layout that had
/// been refactored away.
List<String> _validateGoldenTree(Directory goldenRoot, List<String> declared) {
  final onDisk =
      goldenRoot
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: goldenRoot.path))
          .map((rel) => p.split(rel).join('/'))
          .toList()
        ..sort();

  final problems = <String>[
    for (final rel in declared)
      if (!onDisk.contains(rel)) '  missing golden file: $rel',
    for (final rel in onDisk)
      if (!declared.contains(rel)) '  golden file no variant copies: $rel',
  ];
  return problems;
}

void _copyGoldenFile(
  String goldenRootPath,
  String repoRootPath,
  String relativePath,
) {
  final src = File(p.join(goldenRootPath, relativePath));
  if (!src.existsSync()) {
    throw StateError('Missing golden file: ${src.path}');
  }
  final dest = File(p.join(repoRootPath, relativePath));
  dest.parent.createSync(recursive: true);
  src.copySync(dest.path);
}

void _deleteDir(Directory dir) {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

/// Deletes every entry in [_processOnlyPaths], then prunes the directories
/// those deletions emptied.
///
/// A missing entry is skipped rather than reported: a fork that already deleted
/// its own copy of one of these is not an error.
void _removeProcessArtifacts(Directory repoRoot) {
  for (final relative in _processOnlyPaths) {
    final path = p.join(repoRoot.path, relative);
    final dir = Directory(path);
    final file = File(path);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    } else if (file.existsSync()) {
      file.deleteSync();
    } else {
      continue;
    }
    stdout.writeln(
      "Removed $relative: it serves this repository's issue loop, not the "
      'app a fork ships.',
    );
  }

  for (final relative in _processOnlyPrunedDirs) {
    final dir = Directory(p.join(repoRoot.path, relative));
    if (dir.existsSync() && dir.listSync().isEmpty) {
      dir.deleteSync();
      stdout.writeln('Removed $relative: emptied by the removals above.');
    }
  }
}

/// Every markdown file that could carry a process-only marker.
///
/// `docs/verification/` is skipped: the whole tree is deleted anyway, and its
/// files quote captured terminal output, so a marker-shaped string inside one
/// is a transcript rather than an instruction.
List<File> _markdownFiles(Directory repoRoot) {
  final found = <File>[];

  void walk(Directory dir) {
    if (!dir.existsSync()) {
      return;
    }
    for (final entity in dir.listSync(followLinks: false)) {
      final relative = p.split(p.relative(entity.path, from: repoRoot.path));
      if (entity is Directory) {
        if (_markdownWalkSkips.contains(relative.last)) {
          continue;
        }
        if (relative.length == 2 &&
            relative[0] == 'docs' &&
            relative[1] == 'verification') {
          continue;
        }
        walk(entity);
      } else if (entity is File && entity.path.endsWith('.md')) {
        found.add(entity);
      }
    }
  }

  walk(repoRoot);
  return found;
}

/// Reports markers that do not pair up, before anything has been deleted.
///
/// An unclosed start marker would silently swallow the rest of a file an
/// adopter keeps - `CONTRIBUTING.md` from its issue callout to its last line,
/// say - and the only signal would be a shorter file nobody diffed.
List<String> _validateProcessMarkers(Directory repoRoot) {
  final problems = <String>[];
  for (final file in _markdownFiles(repoRoot)) {
    final relative = p.relative(file.path, from: repoRoot.path);
    var openedAt = 0;
    var lineNumber = 0;
    for (final line in file.readAsLinesSync()) {
      lineNumber++;
      final trimmed = line.trim();
      if (trimmed == _processMarkerStart) {
        if (openedAt != 0) {
          problems.add(
            '  $relative:$lineNumber: start marker inside the region opened '
            'at line $openedAt',
          );
        }
        openedAt = lineNumber;
      } else if (trimmed == _processMarkerEnd) {
        if (openedAt == 0) {
          problems.add('  $relative:$lineNumber: end marker with no start');
        }
        openedAt = 0;
      }
    }
    if (openedAt != 0) {
      problems.add('  $relative:$openedAt: start marker is never closed');
    }
  }
  return problems;
}

/// Removes every `<!-- strip:process-only ... -->` region from markdown files
/// the strip keeps.
///
/// Used where deleting the whole file would be wrong: `CLAUDE.md` still
/// describes the codebase after the issue loop is gone, `CONTRIBUTING.md` still
/// describes how to open a pull request, and `tool/README.md` still documents
/// the tools that survive. Only the marked block goes; the surrounding prose is
/// the file's own.
void _stripProcessMarkdownRegions(Directory repoRoot) {
  for (final file in _markdownFiles(repoRoot)) {
    final kept = <String>[];
    var dropping = false;
    var justClosed = false;
    var dropped = 0;

    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed == _processMarkerStart) {
        dropping = true;
        continue;
      }
      if (trimmed == _processMarkerEnd) {
        dropping = false;
        justClosed = true;
        dropped++;
        continue;
      }
      if (dropping) {
        continue;
      }
      // A region is normally surrounded by blank lines; keeping both would
      // leave a double blank where the section used to be.
      if (justClosed) {
        justClosed = false;
        if (trimmed.isEmpty && (kept.isEmpty || kept.last.trim().isEmpty)) {
          continue;
        }
      }
      kept.add(line);
    }

    if (dropped == 0) {
      continue;
    }
    file.writeAsStringSync('${kept.join('\n')}\n');
    stdout.writeln(
      'Dropped $dropped process-only section(s) from '
      '${p.relative(file.path, from: repoRoot.path)}.',
    );
  }
}

void _patchTestFixtures(String path) {
  final file = File(path);
  var s = file.readAsStringSync().replaceAll('\r\n', '\n');
  s = s.replaceAll(
    "import 'package:flutter_starter/features/tasks/data/models/task_model.dart';\n",
    '',
  );
  s = s.replaceAll(
    "import 'package:flutter_starter/features/tasks/domain/entities/task.dart';\n",
    '',
  );
  const marker =
      '// ============================================================================\n// Task Fixtures';
  final idx = s.indexOf(marker);
  if (idx == -1) {
    throw StateError('Task Fixtures section not found in test_fixtures.dart');
  }
  file.writeAsStringSync('${s.substring(0, idx).trimRight()}\n');
}

void _patchMockFactories(String path) {
  var s = File(path).readAsStringSync().replaceAll('\r\n', '\n');
  s = s.replaceAll(
    RegExp(r"import 'package:flutter_starter/features/tasks/[^']+';\n"),
    '',
  );
  final a = s.indexOf(
    '// ============================================================================\n// Tasks Feature Mocks',
  );
  final b = a == -1
      ? -1
      : s.indexOf(
          '// ============================================================================\n// Mock Factories',
          a,
        );
  if (a != -1 && b != -1) {
    s = '${s.substring(0, a)}${s.substring(b)}';
  }
  final c = s.indexOf('/// Creates a configured mock TasksRepository');
  if (c != -1) {
    s = '${s.substring(0, c).trimRight()}\n';
  }
  File(path).writeAsStringSync(s);
}

void _patchProvidersTest(String path) {
  var lines = File(path).readAsLinesSync();
  lines = lines
      .where((l) => !l.contains('package:flutter_starter/features/tasks/'))
      .toList();
  final start = lines.indexWhere((l) => l.contains("group('Tasks Providers'"));
  final end = lines.indexWhere(
    (l) => l.contains("group('Provider Instance Types'"),
  );
  if (start == -1 || end == -1 || start >= end) {
    throw StateError(
      'Could not locate Tasks provider groups in providers_test.dart',
    );
  }
  lines = [...lines.sublist(0, start), ...lines.sublist(end)];
  File(path).writeAsStringSync('${lines.join('\n')}\n');
}

/// Deletes evidence probes under `docs/verification/` that import a stripped
/// module.
///
/// `analysis_options.yaml` does not exclude `docs/`, so a `.dart` file
/// committed as acceptance evidence is analyzed like any other source - a
/// property `CLAUDE.md` states on purpose. The strip therefore has to account
/// for it: on koniz-dev/flutter-starter#171 the probe at
/// `docs/verification/issue-146/timestamp_probe.dart` imported
/// `features/tasks/data/models/task_model.dart`, the strip exited 0, and both
/// tasks-removing variants of `strip-smoke.yml` then failed two steps later in
/// `flutter analyze` with `uri_does_not_exist`.
///
/// Deleting is the right verb rather than rewriting or warning. The script
/// already deletes `docs/features/tasks.md` for the same reason: a tree with
/// the tasks sample stripped out has no use for this repository's evidence
/// about the tasks sample, and a fork running the strip wants a buildable
/// starter, not an archive. Every deletion is printed, so nothing vanishes
/// silently, and only `.dart` files that actually name a stripped module are
/// touched - the surrounding `README.md` and logs are left alone.
///
/// Scoped to `docs/verification/` on purpose, not to all of `docs/`. That
/// subtree is per-issue acceptance evidence and nothing imports it, so
/// deleting from it is safe. A Dart file anywhere else under `docs/` is
/// something a human wrote to be read; the strip must not quietly delete it,
/// so it falls through to `_collectStrippedViolations` and fails the run
/// loudly instead.
void _deleteDocsProbes(Directory repoRoot, List<String> needles) {
  if (needles.isEmpty) {
    return;
  }
  final docs = Directory(p.join(repoRoot.path, 'docs', 'verification'));
  if (!docs.existsSync()) {
    return;
  }
  for (final entity in docs.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final text = entity.readAsStringSync();
    final hit = needles.where(text.contains).toList();
    if (hit.isEmpty) {
      continue;
    }
    entity.deleteSync();
    stdout.writeln(
      'Deleted ${p.relative(entity.path, from: repoRoot.path)}: an evidence '
      'probe importing a stripped module (${hit.join(', ')}). '
      'docs/ is analyzed, so leaving it would break flutter analyze.',
    );
  }
}

/// Regex for one `<!-- symbol: <path> <name> -->` directive line.
final RegExp _symbolDirectivePattern = RegExp(
  r'^\s*<!--\s*symbol:\s*(\S+)\s+\S+\s*-->\s*$',
);

/// Drops `<!-- symbol: ... -->` directives that name a path under [prefixes].
///
/// The directives are checked by `tool/doc_symbols.dart` from both
/// `tool/check_docs.dart` and `test/docs/doc_symbols_test.dart`. The second of
/// those runs under `flutter test`, which every strip variant runs in
/// `strip-smoke.yml`, so a directive pointing into a deleted feature would
/// fail a stripped tree. Only the directive line is removed; the prose around
/// it is a human's to rewrite, and a wrong sentence in a stripped fork is a
/// smaller problem than a red build.
void _deleteSymbolDirectives(Directory repoRoot, List<String> prefixes) {
  if (prefixes.isEmpty) {
    return;
  }
  final docs = Directory(p.join(repoRoot.path, 'docs'));
  if (!docs.existsSync()) {
    return;
  }
  for (final entity in docs.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.md')) {
      continue;
    }
    final lines = entity.readAsLinesSync();
    final kept = <String>[];
    var dropped = 0;
    for (final line in lines) {
      final match = _symbolDirectivePattern.firstMatch(line);
      if (match != null &&
          prefixes.any((prefix) => match.group(1)!.startsWith(prefix))) {
        dropped++;
        continue;
      }
      kept.add(line);
    }
    if (dropped == 0) {
      continue;
    }
    entity.writeAsStringSync('${kept.join('\n')}\n');
    stdout.writeln(
      'Dropped $dropped symbol directive(s) naming a stripped path from '
      '${p.relative(entity.path, from: repoRoot.path)}.',
    );
  }
}

/// Scans every Dart source the analyzer reads for stripped module imports that
/// would no longer resolve.
///
/// `docs` is in the list because `analysis_options.yaml` does not exclude it,
/// so `flutter analyze` reads `docs/**/*.dart` too. `_deleteDocsProbes` has
/// already removed the offending files under `docs/verification/`; this scan
/// is what catches the rest of `docs/`, and it fails the run loudly and
/// locally rather than leaving CI to discover it two steps later, which is
/// what happened on koniz-dev/flutter-starter#171.
List<String> _collectStrippedViolations(
  Directory repoRoot,
  List<String> needles,
) {
  final violations = <String>[];
  final roots = [
    Directory(p.join(repoRoot.path, 'lib')),
    Directory(p.join(repoRoot.path, 'test')),
    Directory(p.join(repoRoot.path, 'integration_test')),
    Directory(p.join(repoRoot.path, 'examples')),
    Directory(p.join(repoRoot.path, 'docs')),
  ];

  for (final dir in roots) {
    if (!dir.existsSync()) {
      continue;
    }
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final text = entity.readAsStringSync();
      for (final n in needles) {
        if (text.contains(n)) {
          violations.add('${entity.path}: references stripped module ($n)');
        }
      }
    }
  }

  return violations;
}
