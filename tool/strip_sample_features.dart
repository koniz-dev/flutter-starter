// Removes sample `tasks` and `feature_flags` feature modules and rewires
// the app using golden files under tool/golden/<variant>/.
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

void main(List<String> args) {
  if (!args.contains('--apply')) {
    stderr.writeln(
      'Usage: dart run tool/strip_sample_features.dart --apply '
      '[--remove-tasks] [--remove-feature-flags]\n'
      'Removes lib/features/tasks, lib/features/feature_flags, related tests, '
      'and core FeatureFlagsManager. Rewires entrypoints from '
      'tool/golden/<variant>/. Keeps auth sample.',
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

  _patchProviders(
    p.join(root.path, 'lib/core/di/providers.dart'),
    removeTasks: removeTasks,
    removeFeatureFlags: removeFeatureFlags,
  );
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

void _patchProviders(
  String path, {
  required bool removeTasks,
  required bool removeFeatureFlags,
}) {
  final file = File(path);
  var s = file.readAsStringSync().replaceAll('\r\n', '\n');
  if (removeTasks) {
    s = s.replaceAll(
      "export 'package:flutter_starter/features/tasks/di/tasks_providers.dart';\n",
      '',
    );
  }
  if (removeFeatureFlags) {
    s = s.replaceAll(
      "export 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';\n",
      '',
    );
  }
  file.writeAsStringSync(s);
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
