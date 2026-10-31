// Removes sample `tasks` and `feature_flags` feature modules and rewires
// the app using golden files under tool/golden/<variant>/.
//
// Usage (from repository root):
//   dart run tool/strip_sample_features.dart --apply                       both
//   dart run tool/strip_sample_features.dart --apply --remove-tasks
//   dart run tool/strip_sample_features.dart --apply --remove-feature-flags
//   dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks
//
// Add --remove-bricks to any of them to also delete bricks/ and mason.yaml,
// with the documentation that links into them. --keep-samples removes neither
// sample, so with --remove-bricks it drops only the Mason bricks.
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
/// it composes the tasks and feature-flags route modules, so every
/// variant needs its own copy.
///
/// The `test/core/routing/` files are deliberately absent: those tests
/// assert only the routes every variant keeps, and each sample feature
/// asserts its own routing in `test/features/<feature>/routing/`, which the
/// strip deletes with the feature. Three near-identical copies of a test file
/// is how the `stripped` copy of `app_router_test.dart` silently stayed on
/// an outdated router.
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

/// Tags of the markdown markers this strip understands.
///
/// Whole files are cheap to delete; a section inside a file an adopter keeps is
/// not, and hand-written path lists rot. So prose that documents something a
/// strip removes is marked in place, with an HTML comment that is invisible in
/// rendered markdown and ignored by `tool/check_docs.dart`:
///
///   * a block, between `<!-- strip:<tag> start -->` and
///     `<!-- strip:<tag> end -->` lines;
///   * a single line - a table row, say, where a marker line would end the
///     table - carrying `<!-- strip:<tag> line -->` anywhere on it.
///
/// `strip-tool` regions document this tool itself, and go when it removes
/// itself after a sample strip.
/// `feature-flags` and `tasks` regions go with their sample, and stay,
/// invisible, while the sample is kept. `bricks` regions go with `bricks/`
/// and `mason.yaml` under `--remove-bricks`.
const _featureFlagsTag = 'feature-flags';
const _tasksTag = 'tasks';
const _bricksTag = 'bricks';
const _stripToolTag = 'strip-tool';
const _markerTags = <String>[
  _featureFlagsTag,
  _tasksTag,
  _bricksTag,
  _stripToolTag,
];

/// What exists only to run this strip. Once it has removed a sample, running it
/// again is not supported, so after a sample strip it deletes all of it - the
/// adopter keeps nothing whose only job was producing their tree.
/// `--keep-samples` keeps it, because the
/// samples can still be removed later.
const _selfPaths = <String>[
  'tool/strip_sample_features.dart',
  'tool/golden',
  '.github/workflows/strip-smoke.yml',
  'test/tooling/strip_markers_test.dart',
  'test/tooling/strip_sample_prose_test.dart',
  'test/tooling/strip_rerun_test.dart',
  'test/tooling/strip_unknown_flags_test.dart',
];

/// The analyzer exclude for [_selfPaths]' golden tree, with its comment.
const _goldenExcludeBlock = '''
    # Golden tree mirrors lib/ for strip_sample_features; not part of the app.
    # Analyzing these in place would measure them against the unstripped
    # sources they exist to replace, so the exclusion stays. Coverage comes
    # from .github/workflows/strip-smoke.yml instead: it applies each strip
    # variant and analyzes the resulting tree, which is the only state in
    # which a golden's correctness is a meaningful question.
    - tool/golden/**
''';

/// What `--remove-bricks` deletes: the Mason bricks, their registry, and the
/// test of the bricks' input rules, which imports them.
const _brickPaths = <String>[
  'bricks',
  'mason.yaml',
  'test/tooling/brick_input_rules_test.dart',
];

String _markerStart(String tag) => '<!-- strip:$tag start -->';
String _markerEnd(String tag) => '<!-- strip:$tag end -->';
String _markerLine(String tag) => '<!-- strip:$tag line -->';

/// Directory names never walked when looking for markdown.
const _markdownWalkSkips = <String>{
  '.dart_tool',
  '.git',
  '.idea',
  'build',
  'node_modules',
};

/// Every flag the tool reads. `--tasks-only` and `--feature-flags-only` are
/// the setup brick's spellings of the two remove flags.
const _knownFlags = <String>{
  '--apply',
  '--remove-tasks',
  '--remove-feature-flags',
  '--tasks-only',
  '--feature-flags-only',
  '--keep-samples',
  '--remove-bricks',
};

const _usage =
    'Usage: dart run tool/strip_sample_features.dart --apply '
    '[--remove-tasks] [--remove-feature-flags] | --keep-samples '
    '[--remove-bricks]\n'
    'Removes lib/features/tasks, lib/features/feature_flags and related '
    'tests. Rewires entrypoints from '
    'tool/golden/<variant>/. Keeps auth sample. --keep-samples removes '
    'neither sample. --remove-bricks also deletes bricks/ and mason.yaml, '
    'and the docs that link into them.';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }
  // Checked before anything else. Flags are read with `contains`, so an
  // unknown one used to be dropped in silence: `--keep-sample` (one letter
  // short) left neither sample flag set, which means "remove both", and the
  // tool deleted both samples, bricks/ and itself.
  final unknown = args.where((a) => !_knownFlags.contains(a)).toList();
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'Unknown option${unknown.length == 1 ? '' : 's'}: ${unknown.join(' ')}. '
      'Nothing was deleted.\n$_usage',
    );
    exitCode = 64;
    return;
  }
  if (!args.contains('--apply')) {
    stderr.writeln(_usage);
    exitCode = 1;
    return;
  }

  final tasksFlag =
      args.contains('--tasks-only') || args.contains('--remove-tasks');
  final featureFlagsFlag =
      args.contains('--feature-flags-only') ||
      args.contains('--remove-feature-flags');

  // Removes neither sample, so an adopter keeping both can still drop the
  // Mason bricks.
  final keepSamples = args.contains('--keep-samples');
  // Deleting bricks/ by hand left seven links dangling in docs a fork keeps,
  // so the documented way to drop them is this flag, which takes their
  // `strip:bricks` prose along.
  final removeBricks = args.contains('--remove-bricks');
  // The tree to strip is the current directory, and only a project root
  // qualifies: run from test/, the tool wrote test/lib/... and
  // test/test/... and crashed halfway.
  final root = Directory.current;
  final scriptDir = File.fromUri(Platform.script).parent;
  if (!File(p.join(root.path, 'pubspec.yaml')).existsSync() ||
      !File(p.join(root.path, 'tool/strip_sample_features.dart'))
          .existsSync()) {
    stderr.writeln(
      'Run this from the project root (the directory holding pubspec.yaml '
      'and tool/strip_sample_features.dart); ${root.path} is not one. '
      'Nothing was deleted.',
    );
    exitCode = 2;
    return;
  }

  if (keepSamples && (tasksFlag || featureFlagsFlag)) {
    stderr.writeln(
      '--keep-samples keeps both samples; it cannot be combined with '
      '--remove-tasks or --remove-feature-flags. Nothing was deleted.',
    );
    exitCode = 1;
    return;
  }
  if (keepSamples) {
    // Validated in every mode, so a bad marker is reported even by a run that
    // would remove nothing.
    final markerProblems = _validateMarkers(root);
    if (markerProblems.isNotEmpty) {
      stderr.writeln(
        'Strip markers are unbalanced; nothing was deleted:\n'
        '${markerProblems.join('\n')}',
      );
      exitCode = 2;
      return;
    }
    if (!removeBricks) {
      stdout.writeln(
        'Nothing to remove: --keep-samples keeps both samples. Add '
        '--remove-bricks to drop the Mason bricks.',
      );
      return;
    }
    _removeBricks(root);
    _stripMarkdownRegions(root, const [_bricksTag]);
    stdout.writeln(
      'Bricks removed; both samples kept. '
      'Run: flutter pub get && flutter analyze && flutter test',
    );
    return;
  }

  // Naming both samples is the same request as naming neither: remove both.
  // This used to fall through to `removeBoth == false`, which deleted both
  // feature trees, installed the `no_tasks` golden over them and only then
  // exited 3 - an unbuildable tree with no way back short of git.
  final removeBoth = tasksFlag == featureFlagsFlag;
  final removeTasks = removeBoth || tasksFlag;
  final removeFeatureFlags = removeBoth || featureFlagsFlag;

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
  final markerProblems = _validateMarkers(root);
  if (markerProblems.isNotEmpty) {
    stderr.writeln(
      'Strip markers are unbalanced; nothing was deleted:\n'
      '${markerProblems.join('\n')}',
    );
    exitCode = 2;
    return;
  }

  if (removeBricks) _removeBricks(root);
  _stripMarkdownRegions(root, [
    if (removeBricks) _bricksTag,
    if (removeFeatureFlags) _featureFlagsTag,
    if (removeTasks) _tasksTag,
  ]);

  if (removeTasks) {
    _deleteDir(Directory(p.join(root.path, 'lib/features/tasks')));
    _deleteDir(Directory(p.join(root.path, 'test/features/tasks')));
  }
  if (removeFeatureFlags) {
    _deleteDir(Directory(p.join(root.path, 'lib/features/feature_flags')));
    _deleteDir(Directory(p.join(root.path, 'test/features/feature_flags')));
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
  _sortGoldenImports(root, overrides);

  // `lib/core/di/providers.dart` needs no patching: it names no feature at
  // all, now that the three backward-compatibility re-exports this step used
  // to strip are gone.
  if (removeTasks) {
    _patchTestFixtures(p.join(root.path, 'test/helpers/test_fixtures.dart'));
    _patchMockFactories(p.join(root.path, 'test/helpers/mock_factories.dart'));
    _patchProvidersTest(p.join(root.path, 'test/core/di/providers_test.dart'));
  }

  final needles = <String>[
    if (removeTasks) 'package:flutter_starter/features/tasks/',
    if (removeFeatureFlags) 'package:flutter_starter/features/feature_flags/',
  ];

  // Documentation asserts identifiers with
  // `<!-- symbol: <path> <name> -->`, and
  // `test/docs/doc_symbols_test.dart` fails the run when one does not resolve.
  // A directive naming a file this strip just deleted would therefore turn
  // every stripped variant red in `flutter test`, so the directives go with
  // the files.
  _deleteSymbolDirectives(root, [
    if (removeTasks) 'lib/features/tasks/',
    if (removeFeatureFlags) 'lib/features/feature_flags/',
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

  _removeSelf(root);

  stdout.writeln(
    'Strip complete. Run: flutter pub get && flutter analyze && flutter test',
  );
}

/// Deletes [_selfPaths] and the docs about this tool, then unwraps every
/// marker left - those of a kept sample or kept bricks - keeping its text, so
/// no `strip:` marker survives in a tree with no strip tool to read it.
void _removeSelf(Directory root) {
  _stripMarkdownRegions(root, const [_stripToolTag]);
  _unwrapMarkers(root);

  final options = File(p.join(root.path, 'analysis_options.yaml'));
  if (options.existsSync()) {
    final text = options.readAsStringSync();
    if (text.contains(_goldenExcludeBlock)) {
      options.writeAsStringSync(text.replaceFirst(_goldenExcludeBlock, ''));
    }
  }

  for (final relative in _selfPaths) {
    final path = p.join(root.path, relative);
    if (FileSystemEntity.isDirectorySync(path)) {
      Directory(path).deleteSync(recursive: true);
    } else if (FileSystemEntity.isFileSync(path)) {
      File(path).deleteSync();
    } else {
      continue;
    }
    stdout.writeln('Removed $relative: it only serves this strip.');
  }
}

/// Removes every remaining marker but keeps the text it marked: block marker
/// lines go, and a line marker is cut out of its line.
void _unwrapMarkers(Directory repoRoot) {
  final lineMarker = RegExp(r'\s*<!-- strip:[\w-]+ line -->');
  final blockMarker = RegExp(r'^\s*<!-- strip:[\w-]+ (start|end) -->\s*$');
  for (final file in _markdownFiles(repoRoot)) {
    final lines = file.readAsLinesSync();
    final kept = [
      for (final line in lines)
        if (!blockMarker.hasMatch(line)) line.replaceAll(lineMarker, ''),
    ];
    if (kept.join('\n') == lines.join('\n')) continue;
    file.writeAsStringSync('${kept.join('\n')}\n');
  }
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

/// Sorts the imports of the golden files just copied in.
///
/// They are written in the order sorted for the package name `flutter_starter`,
/// and a rename rewrites that name inside them. After a rename to one that
/// sorts elsewhere (`my_app` after `flutter_test`), the order trips
/// `directives_ordering` - so the analyzer sorts them, as
/// `scripts/dev/create_feature.sh` and the feature brick do. A failure is
/// reported, not fatal: the tree still builds, and `flutter analyze` names
/// the file.
void _sortGoldenImports(Directory root, List<String> copied) {
  for (final relative in copied.where((f) => f.endsWith('.dart'))) {
    final result = Process.runSync(
      'dart',
      [
        'fix',
        '--apply',
        '--code=directives_ordering',
        relative,
      ],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      stderr.writeln(
        'Could not sort the imports of $relative; run '
        '`dart fix --apply --code=directives_ordering $relative`.',
      );
    }
  }
}

void _deleteDir(Directory dir) {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

/// Deletes [_brickPaths]. A path already gone - a second run - is skipped.
void _removeBricks(Directory repoRoot) {
  for (final relative in _brickPaths) {
    final path = p.join(repoRoot.path, relative);
    if (FileSystemEntity.isDirectorySync(path)) {
      Directory(path).deleteSync(recursive: true);
    } else if (FileSystemEntity.isFileSync(path)) {
      File(path).deleteSync();
    } else {
      continue;
    }
    stdout.writeln('Removed $relative (--remove-bricks).');
  }
}

/// Every markdown file that could carry a strip marker.
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
/// say - and the only signal would be a shorter file nobody diffed. Every tag
/// is checked in every variant, so a bad feature marker fails even a strip
/// that would have kept that region.
List<String> _validateMarkers(Directory repoRoot) {
  final problems = <String>[];
  for (final file in _markdownFiles(repoRoot)) {
    final relative = p.relative(file.path, from: repoRoot.path);
    final openedAt = <String, int>{};
    var lineNumber = 0;
    for (final line in file.readAsLinesSync()) {
      lineNumber++;
      final trimmed = line.trim();
      for (final tag in _markerTags) {
        if (trimmed == _markerStart(tag)) {
          if (openedAt.isNotEmpty) {
            problems.add(
              '  $relative:$lineNumber: $tag start marker inside the region '
              'opened at line ${openedAt.values.first}',
            );
          }
          openedAt[tag] = lineNumber;
        } else if (trimmed == _markerEnd(tag)) {
          if (!openedAt.containsKey(tag)) {
            problems.add(
              '  $relative:$lineNumber: $tag end marker with no start',
            );
          }
          openedAt.remove(tag);
        } else if (openedAt.containsKey(tag) &&
            line.contains(_markerLine(tag))) {
          // A line marker of another tag inside a block is fine: each goes
          // with its own strip. One of the same tag would be redundant.
          problems.add(
            '  $relative:$lineNumber: $tag line marker inside the $tag region '
            'opened at line ${openedAt[tag]}',
          );
        }
      }
    }
    openedAt.forEach((tag, at) {
      problems.add('  $relative:$at: $tag start marker is never closed');
    });
  }
  return problems;
}

/// Removes every region and marked line for [tags] from the markdown files
/// the strip keeps.
///
/// Used where deleting the whole file would be wrong: `README.md` still
/// introduces the project once the bricks are gone, and
/// `docs/guides/configuration.md` still documents configuration once the
/// feature-flags sample is gone. Only the marked prose
/// goes; the surrounding prose is the file's own.
void _stripMarkdownRegions(Directory repoRoot, List<String> tags) {
  for (final file in _markdownFiles(repoRoot)) {
    final kept = <String>[];
    var dropping = false;
    var justClosed = false;
    var dropped = 0;

    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (tags.any((tag) => trimmed == _markerStart(tag))) {
        dropping = true;
        continue;
      }
      if (tags.any((tag) => trimmed == _markerEnd(tag))) {
        dropping = false;
        justClosed = true;
        dropped++;
        continue;
      }
      if (dropping) {
        continue;
      }
      if (tags.any((tag) => line.contains(_markerLine(tag)))) {
        dropped++;
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
      'Dropped $dropped marked section(s) or line(s) from '
      '${p.relative(file.path, from: repoRoot.path)}.',
    );
  }
}

void _patchTestFixtures(String path) {
  final file = File(path);
  if (!file.existsSync()) return;
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
  // Already gone on a re-run after a partial strip; any task reference left
  // is still caught by the forbidden-reference scan.
  file.writeAsStringSync(
    idx == -1 ? s : '${s.substring(0, idx).trimRight()}\n',
  );
}

void _patchMockFactories(String path) {
  if (!File(path).existsSync()) return;
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
  if (!File(path).existsSync()) return;
  var lines = File(path).readAsLinesSync();
  lines = lines
      .where((l) => !l.contains('package:flutter_starter/features/tasks/'))
      .toList();
  final start = lines.indexWhere((l) => l.contains("group('Tasks Providers'"));
  final end = lines.indexWhere(
    (l) => l.contains("group('Provider Instance Types'"),
  );
  if (start == -1) {
    // Already removed by an earlier, partial run.
    File(path).writeAsStringSync('${lines.join('\n')}\n');
    return;
  }
  if (end == -1 || start >= end) {
    throw StateError(
      'Could not locate Tasks provider groups in providers_test.dart',
    );
  }
  lines = [...lines.sublist(0, start), ...lines.sublist(end)];
  File(path).writeAsStringSync('${lines.join('\n')}\n');
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
/// so `flutter analyze` reads `docs/**/*.dart` too. This scan fails the run
/// loudly and locally rather than leaving CI to discover it two steps later,
/// which is what happened once.
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

  return _withoutIgnored(repoRoot, violations);
}

/// [violations] minus those in files git ignores: a generated, git-ignored
/// file (the coverage helper imports every library) is not part of the tree
/// being stripped, and failing on one left a half-stripped tree. Outside a git
/// repository nothing is dropped.
List<String> _withoutIgnored(Directory repoRoot, List<String> violations) {
  if (violations.isEmpty) return violations;
  final paths = {for (final v in violations) v.split(': ').first};
  final ProcessResult result;
  try {
    result = Process.runSync('git', [
      'check-ignore',
      '--',
      ...paths,
    ], workingDirectory: repoRoot.path);
  } on ProcessException {
    return violations;
  }
  // 0: some ignored; 1: none ignored; anything else: not a repository.
  if (result.exitCode != 0) return violations;
  final ignored = {
    for (final line in (result.stdout as String).split('\n'))
      if (line.trim().isNotEmpty)
        p.normalize(p.absolute(repoRoot.path, line.trim())),
  };
  return [
    for (final v in violations)
      if (!ignored.contains(p.normalize(p.absolute(v.split(': ').first)))) v,
  ];
}
