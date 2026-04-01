// Removes sample `tasks` and `feature_flags` feature modules and rewires
// the app using golden files under tool/golden/stripped/.
//
// Usage (from repository root):
//   dart run tool/strip_sample_features.dart --apply
//
// Then:
//   flutter pub get && flutter analyze && flutter test

import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) {
  if (!args.contains('--apply')) {
    stderr.writeln(
      'Usage: dart run tool/strip_sample_features.dart --apply\n'
      'Removes lib/features/tasks, lib/features/feature_flags, related tests, '
      'and core FeatureFlagsManager. Rewires entrypoints from '
      'tool/golden/stripped/. Keeps auth sample.',
    );
    exitCode = 1;
    return;
  }

  final removeTasks =
      args.contains('--tasks-only') || args.contains('--remove-tasks');
  final removeFeatureFlags =
      args.contains('--feature-flags-only') ||
      args.contains('--remove-feature-flags');
  final removeBoth = !removeTasks && !removeFeatureFlags;

  final root = Directory.current;
  final scriptDir = File.fromUri(Platform.script).parent;
  final goldenVariant = removeBoth
      ? 'stripped'
      : removeTasks
      ? 'no_tasks'
      : 'no_feature_flags';
  final goldenRoot = Directory(p.join(scriptDir.path, 'golden', goldenVariant));
  if (!goldenRoot.existsSync()) {
    stderr.writeln('Missing golden directory: ${goldenRoot.path}');
    exitCode = 2;
    return;
  }

  if (removeBoth || removeTasks) {
    _deleteDir(Directory(p.join(root.path, 'lib/features/tasks')));
    _deleteDir(Directory(p.join(root.path, 'test/features/tasks')));
  }
  if (removeBoth || removeFeatureFlags) {
    _deleteDir(Directory(p.join(root.path, 'lib/features/feature_flags')));
    _deleteDir(Directory(p.join(root.path, 'test/features/feature_flags')));
    _deleteDir(Directory(p.join(root.path, 'test/core/feature_flags')));
  }

  if (removeBoth || removeFeatureFlags) {
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

  if (removeBoth || removeTasks) {
    final f = File(p.join(root.path, 'docs/features/tasks.md'));
    if (f.existsSync()) {
      f.deleteSync();
    }
  }
  if (removeBoth || removeFeatureFlags) {
    final f = File(p.join(root.path, 'docs/features/feature-flags.md'));
    if (f.existsSync()) {
      f.deleteSync();
    }
  }

  final goldenPath = goldenRoot.path;
  for (final relative in [
    'lib/core/routing/app_router.dart',
    'lib/core/routing/app_router.g.dart',
    'lib/core/routing/routes_registry.dart',
    'lib/core/routing/app_routes.dart',
    'lib/core/routing/navigation_extensions.dart',
    'lib/main.dart',
    'lib/features/home/presentation/screens/home_screen.dart',
    'test/core/routing/app_routes_test.dart',
    'test/core/routing/app_router_test.dart',
    'test/core/routing/navigation_extensions_test.dart',
    'integration_test/app_e2e_test.dart',
    'integration_test/auth_flow_test.dart',
  ]) {
    _copyGoldenFile(goldenPath, root.path, relative);
  }

  if (removeBoth || removeTasks || removeFeatureFlags) {
    _patchProviders(
      p.join(root.path, 'lib/core/di/providers.dart'),
      removeTasks: removeBoth || removeTasks,
      removeFeatureFlags: removeBoth || removeFeatureFlags,
    );
  }
  if (removeBoth || removeTasks) {
    _patchTestFixtures(p.join(root.path, 'test/helpers/test_fixtures.dart'));
    _patchMockFactories(p.join(root.path, 'test/helpers/mock_factories.dart'));
    _patchProvidersTest(p.join(root.path, 'test/core/di/providers_test.dart'));
  }

  final needles = <String>[
    if (removeBoth || removeTasks) 'package:flutter_starter/features/tasks/',
    if (removeBoth || removeFeatureFlags)
      'package:flutter_starter/features/feature_flags/',
    if (removeBoth || removeFeatureFlags)
      'package:flutter_starter/core/feature_flags/feature_flags_manager.dart',
  ];
  final violations = _collectStrippedViolations(root, needles);
  if (violations.isNotEmpty) {
    stderr.writeln(
      'Strip finished but forbidden references remain in app/test code:\n'
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

/// Scans Dart sources under lib/test/integration_test/examples for stripped
/// module imports that would no longer resolve.
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
