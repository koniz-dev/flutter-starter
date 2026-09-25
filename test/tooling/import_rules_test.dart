// Architecture guard: enforces the import rules Clean Architecture relies on
// in this template, so an architecture fix cannot silently regress later.
//
// The guard is *seeded*. `kAllowedImportViolations` records the violations that
// existed when it landed, so it passes on `main` unchanged and each later
// architecture fix deletes exactly one line from it. A guard that lands red is
// a guard that gets disabled.
//
// Two failure directions, both fatal:
//   * a violation that is NOT allowlisted   -> a new regression
//   * an allowlist entry whose violation is -> a stale exemption
//     gone
//
// The second direction is what stops the allowlist outliving the problem it
// documents. Its one deliberate exception is a file that no longer exists at
// all: `strip-smoke.yml` runs `flutter test` on trees where
// `tool/strip_sample_features.dart` has deleted a whole sample feature. See
// `kStrippableSamplePaths`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// The allowlist.
// ---------------------------------------------------------------------------

/// Known, pre-existing import-rule violations: rule id -> offending paths,
/// one path per line, relative to the package root.
///
/// Removing a violation from the tree means deleting exactly one line here. A
/// rule whose list empties keeps an empty set rather than disappearing.
///
/// Do not add to this map to silence a new failure - fix the import instead.
const kAllowedImportViolations = <String, Set<String>>{
  'domain_imports_outer_layer': <String>{},
  'cross_feature_import': <String>{},

  // The one designated mapper outside `lib/core/network/`. Per
  // koniz-dev/flutter-starter#176 it is intentional, not scheduled for a fix:
  // it exists solely to translate `DioException` into a domain exception, and
  // rewriting it without the import would only move the import somewhere less
  // obvious. See docs/api/core/network.md, "Where dio is allowed to appear".
  //
  // #176 already removed the other dio import this guard was specified with,
  // in lib/features/auth/data/datasources/auth_remote_datasource.dart, so it
  // is absent here rather than seeded-and-deleted.
  'dio_outside_core_network': <String>{
    'lib/core/errors/dio_exception_mapper.dart',
  },

  // Empty, and it should stay that way. This guard was specified with three
  // seeded entries here - login_screen.dart, register_screen.dart and
  // task_detail_screen.dart, which navigated with raw `context.go()` /
  // `context.pop()`. koniz-dev/flutter-starter#177 landed while this guard was
  // being written and removed all three, so they are absent rather than
  // seeded-and-deleted.
  'go_router_outside_routing': <String>{},

  // Refs koniz-dev/flutter-starter#118: the `core/di` <-> `features/*/di`
  // cycle. These three are deliberately NOT scheduled for a fix - no epic in
  // `./scripts/bootstrap-issue-labels.sh --list-epics` covers `lib/core/di/`,
  // and breaking the cycle is a sweep across all three slices, not a child
  // issue. They are allowlisted so that they cannot get worse.
  'core_imports_feature': <String>{
    'lib/core/di/providers.dart',
    'lib/core/feature_flags/feature_flags_manager.dart',
    'lib/core/routing/app_router.dart',
  },
};

// ---------------------------------------------------------------------------
// The rules.
// ---------------------------------------------------------------------------

/// A single import-graph rule.
///
/// Every rule states its *allowed* set, not just what it bans: several of these
/// imports are correct by design in specific places, and a failure message that
/// only says "banned" cannot tell a reviewer where the import belongs.
class ImportRule {
  const ImportRule({
    required this.id,
    required this.banned,
    required this.allowedIn,
    required this.violates,
  });

  /// Stable identifier, used as the allowlist key and in failure output.
  final String id;

  /// Human-readable description of the edge this rule governs.
  final String banned;

  /// Human-readable description of where that edge *is* allowed.
  final String allowedIn;

  /// Returns true when importing the second argument from the first breaks
  /// this rule. The first argument is a package-root-relative path using `/`
  /// separators; the second is the directive's URI.
  final bool Function(String sourcePath, String importedUri) violates;
}

/// This package's own `package:` prefix.
const String kPkg = 'package:flutter_starter/';

/// Paths `tool/strip_sample_features.dart` deletes outright.
///
/// `strip-smoke.yml` applies each strip variant and then runs `flutter test`,
/// so this test executes against trees where the sample features are gone. An
/// allowlist entry under one of these prefixes whose file is missing has been
/// stripped, not fixed, and is therefore not stale. An allowlist entry that is
/// missing for any *other* reason is a typo and must fail.
const List<String> kStrippableSamplePaths = <String>[
  'lib/features/tasks/',
  'lib/features/feature_flags/',
  'lib/core/feature_flags/',
];

/// True when [path] is removed by some `--remove-*` strip variant.
bool isStrippableSamplePath(String path) =>
    kStrippableSamplePaths.any(path.startsWith);

/// The registry seam. Composing `buildXRoutes(Ref)` from per-feature route
/// modules is correct as designed, so this is a permanent exemption baked into
/// the rule rather than an allowlist entry.
const String kRoutesRegistry = 'lib/core/routing/routes_registry.dart';

/// `lib/features/<name>/...` -> `<name>`, else null.
String? featureOf(String libPath) =>
    RegExp('^lib/features/([^/]+)/').firstMatch(libPath)?.group(1);

/// `package:flutter_starter/features/<name>/...` -> `<name>`, else null.
String? featureOfUri(String uri) {
  if (!uri.startsWith(kPkg)) return null;
  final rest = uri.substring(kPkg.length);
  return RegExp('^features/([^/]+)/').firstMatch(rest)?.group(1);
}

/// True for the designated per-feature route modules.
bool isFeatureRoutesModule(String libPath) => RegExp(
  r'^lib/features/[^/]+/routing/[^/]+_routes\.dart$',
).hasMatch(libPath);

bool _domainImportsOuterLayer(String sourcePath, String uri) {
  final feature = featureOf(sourcePath);
  if (feature == null) return false;
  if (!sourcePath.startsWith('lib/features/$feature/domain/')) return false;
  return uri.startsWith('${kPkg}features/$feature/data/') ||
      uri.startsWith('${kPkg}features/$feature/presentation/');
}

bool _crossFeatureImport(String sourcePath, String uri) {
  final from = featureOf(sourcePath);
  final to = featureOfUri(uri);
  return from != null && to != null && from != to;
}

bool _dioOutsideCoreNetwork(String sourcePath, String uri) =>
    uri.startsWith('package:dio/') &&
    !sourcePath.startsWith('lib/core/network/');

bool _goRouterOutsideRouting(String sourcePath, String uri) {
  if (!uri.startsWith('package:go_router/')) return false;
  if (sourcePath.startsWith('lib/core/routing/')) return false;
  return !isFeatureRoutesModule(sourcePath);
}

bool _coreImportsFeature(String sourcePath, String uri) {
  if (!sourcePath.startsWith('lib/core/')) return false;
  if (sourcePath == kRoutesRegistry) return false;
  return uri.startsWith('${kPkg}features/');
}

/// Every rule the guard enforces.
const List<ImportRule> kImportRules = <ImportRule>[
  ImportRule(
    id: 'domain_imports_outer_layer',
    banned:
        'a file under lib/features/<f>/domain/ importing that '
        "feature's data/ or presentation/",
    allowedIn:
        'nowhere - domain is the innermost layer and depends on '
        'nothing outside itself',
    violates: _domainImportsOuterLayer,
  ),
  ImportRule(
    id: 'cross_feature_import',
    banned: 'a file under lib/features/<a>/ importing lib/features/<b>/',
    allowedIn:
        'nowhere - features meet through lib/core/ or lib/shared/, '
        'never directly',
    violates: _crossFeatureImport,
  ),
  ImportRule(
    id: 'dio_outside_core_network',
    banned: 'package:dio outside lib/core/network/',
    allowedIn:
        'lib/core/network/** - the dio adapter and the interceptors '
        'that implement the dio Interceptor API - plus the one '
        'designated mapper allowlisted below. Nothing under lib/features/ '
        'may import it. See docs/api/core/network.md, "Where dio is '
        'allowed to appear"',
    violates: _dioOutsideCoreNetwork,
  ),
  ImportRule(
    id: 'go_router_outside_routing',
    banned: 'package:go_router outside the routing layer',
    allowedIn:
        'lib/core/routing/** and the designated per-feature route '
        'modules lib/features/<f>/routing/<name>_routes.dart',
    violates: _goRouterOutsideRouting,
  ),
  ImportRule(
    id: 'core_imports_feature',
    banned: 'lib/core/** importing lib/features/**',
    allowedIn:
        '$kRoutesRegistry only - the route registry seam composes '
        'per-feature route modules by design',
    violates: _coreImportsFeature,
  ),
];

// ---------------------------------------------------------------------------
// Scanning.
// ---------------------------------------------------------------------------

/// A resolved `import` / `export` directive.
class ImportDirective {
  const ImportDirective(this.line, this.uri);

  /// 1-based line number.
  final int line;

  /// The directive's URI, exactly as written.
  final String uri;
}

/// One rule break, at a specific line.
class ImportViolation {
  const ImportViolation({
    required this.rule,
    required this.sourcePath,
    required this.line,
    required this.importedUri,
  });

  final ImportRule rule;
  final String sourcePath;
  final int line;
  final String importedUri;
}

// `export` is a dependency edge too: re-exporting a feature barrel from core
// couples core to that feature exactly as an import does.
final RegExp kDirectivePattern = RegExp(
  r'''^\s*(?:import|export)\s+r?(['"])([^'"]+)\1''',
);

/// Extracts every `import` / `export` URI from Dart [source].
///
/// Line-anchored, so a directive inside a `//` comment is not matched.
List<ImportDirective> parseDirectives(String source) {
  final directives = <ImportDirective>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = kDirectivePattern.firstMatch(lines[i]);
    if (match != null) {
      directives.add(ImportDirective(i + 1, match.group(2)!));
    }
  }
  return directives;
}

/// Applies every rule in [kImportRules] to one directive.
List<ImportViolation> violationsFor(
  String sourcePath,
  ImportDirective directive,
) {
  return <ImportViolation>[
    for (final rule in kImportRules)
      if (rule.violates(sourcePath, directive.uri))
        ImportViolation(
          rule: rule,
          sourcePath: sourcePath,
          line: directive.line,
          importedUri: directive.uri,
        ),
  ];
}

/// Every violation under [libDir], in path order.
List<ImportViolation> scanLib(Directory libDir) {
  final violations = <ImportViolation>[];
  final files =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final sourcePath = file.path.replaceAll(Platform.pathSeparator, '/');
    for (final directive in parseDirectives(file.readAsStringSync())) {
      violations.addAll(violationsFor(sourcePath, directive));
    }
  }
  return violations;
}

bool _isAllowed(ImportViolation v) =>
    (kAllowedImportViolations[v.rule.id] ?? const <String>{}).contains(
      v.sourcePath,
    );

String _describe(ImportViolation v) =>
    '''
  ${v.sourcePath}:${v.line}
      imports : ${v.importedUri}
      rule    : ${v.rule.id}
      banned  : ${v.rule.banned}
      allowed : ${v.rule.allowedIn}''';

void main() {
  final libDir = Directory('lib');

  group('import rules over lib/', () {
    late List<ImportViolation> violations;

    setUpAll(() {
      expect(
        libDir.existsSync(),
        isTrue,
        reason: 'run this test from the package root',
      );
      violations = scanLib(libDir);
    });

    test('no import-rule violation outside the allowlist', () {
      final unexpected = violations.where((v) => !_isAllowed(v)).toList();
      if (unexpected.isEmpty) return;

      final suggestion = unexpected
          .map((v) => "  '${v.rule.id}': { ... '${v.sourcePath}' }")
          .join('\n');

      fail(
        'NEW import-rule violation(s) - ${unexpected.length} found.\n'
        'These break the architecture rules and are not allowlisted:\n\n'
        '${unexpected.map(_describe).join('\n\n')}\n\n'
        'Fix the import. If - and only if - the import is correct as '
        'written, add the path under the matching rule in '
        'kAllowedImportViolations,\n'
        'in test/tooling/import_rules_test.dart:\n\n'
        '$suggestion\n',
      );
    });

    test('no stale allowlist entry', () {
      final live = <String>{
        for (final v in violations) '${v.rule.id} :: ${v.sourcePath}',
      };
      // A file that is gone was stripped, not fixed; the separate test below
      // is what catches a path that is gone for any other reason.
      final stale = <String>[
        for (final entry in kAllowedImportViolations.entries)
          for (final path in entry.value)
            if (File(path).existsSync() &&
                !live.contains('${entry.key} :: $path'))
              '${entry.key}: $path',
      ];
      if (stale.isEmpty) return;

      fail(
        'STALE allowlist entr(ies) - ${stale.length} found.\n'
        'kAllowedImportViolations exempts these, but the violation no longer '
        'exists in lib/ (it was fixed, the file moved, or the path is '
        'misspelt).\n'
        'An exemption that outlives its violation silently re-opens the '
        'hole, so delete the line(s) from\n'
        'test/tooling/import_rules_test.dart:\n\n'
        '${stale.map((e) => '  $e').join('\n')}\n',
      );
    });

    test('every allowlist key names a real rule', () {
      final ruleIds = kImportRules.map((r) => r.id).toSet();
      for (final key in kAllowedImportViolations.keys) {
        expect(
          ruleIds,
          contains(key),
          reason: "allowlist key '$key' names no rule in kImportRules",
        );
      }
    });

    test('every allowlist path exists, unless it is a stripped sample', () {
      for (final entry in kAllowedImportViolations.entries) {
        for (final path in entry.value) {
          expect(
            File(path).existsSync() || isStrippableSamplePath(path),
            isTrue,
            reason:
                "allowlist entry '${entry.key}: $path' names a file that "
                'does not exist and is not removable by '
                'tool/strip_sample_features.dart - check it for a typo',
          );
        }
      }
    });

    test('every rule has exactly one allowlist key', () {
      final ruleIds = kImportRules.map((r) => r.id).toSet();
      expect(ruleIds, hasLength(kImportRules.length));
      expect(kAllowedImportViolations.keys.toSet(), ruleIds);
    });
  });

  // These prove the rules actually fire. Without them a rule whose predicate
  // silently returned false would pass every run above and guard nothing.
  group('rule predicates', () {
    String pkg(String path) => '$kPkg$path';

    String? ruleFor(String path, String uri) {
      final hits = violationsFor(path, ImportDirective(1, uri));
      return hits.isEmpty ? null : hits.single.rule.id;
    }

    const domainFile = 'lib/features/tasks/domain/usecases/x_usecase.dart';
    const screenFile = 'lib/features/tasks/presentation/screens/x_screen.dart';
    const goRouter = 'package:go_router/go_router.dart';
    const dio = 'package:dio/dio.dart';

    test('domain importing its own data or presentation is a violation', () {
      expect(
        ruleFor(domainFile, pkg('features/tasks/data/models/task_model.dart')),
        'domain_imports_outer_layer',
      );
      expect(
        ruleFor(
          domainFile,
          pkg('features/tasks/presentation/providers/tasks_provider.dart'),
        ),
        'domain_imports_outer_layer',
      );
    });

    test('domain importing its own domain, core or a pub package is fine', () {
      expect(
        ruleFor(domainFile, pkg('features/tasks/domain/entities/task.dart')),
        isNull,
      );
      expect(ruleFor(domainFile, pkg('core/errors/failures.dart')), isNull);
      expect(ruleFor(domainFile, 'package:dartz/dartz.dart'), isNull);
    });

    test('data importing presentation is outside this rule set', () {
      // Documented gap: the specified rule covers domain -> outer only. There
      // are zero data -> presentation edges in lib/ today.
      expect(
        ruleFor(
          'lib/features/tasks/data/models/task_model.dart',
          pkg('features/tasks/presentation/screens/x_screen.dart'),
        ),
        isNull,
      );
    });

    test('one feature importing another is a violation', () {
      expect(
        ruleFor(screenFile, pkg('features/auth/domain/entities/user.dart')),
        'cross_feature_import',
      );
    });

    test('a feature importing itself, core or shared is fine', () {
      expect(
        ruleFor(screenFile, pkg('features/tasks/domain/entities/task.dart')),
        isNull,
      );
      expect(ruleFor(screenFile, pkg('core/constants/ui_keys.dart')), isNull);
      expect(
        ruleFor(screenFile, pkg('shared/widgets/app_button.dart')),
        isNull,
      );
    });

    test('lib/features importing lib/core is fine - that is the direction', () {
      expect(
        ruleFor(
          'lib/features/auth/di/auth_providers.dart',
          pkg('core/di/providers.dart'),
        ),
        isNull,
      );
    });

    test('package:dio is allowed only under lib/core/network/', () {
      expect(ruleFor('lib/core/network/api_client.dart', dio), isNull);
      expect(
        ruleFor('lib/core/network/adapters/dio_network_client.dart', dio),
        isNull,
      );
      expect(
        ruleFor('lib/core/errors/dio_exception_mapper.dart', dio),
        'dio_outside_core_network',
      );
      expect(
        ruleFor(
          'lib/features/auth/data/datasources/auth_remote_datasource.dart',
          dio,
        ),
        'dio_outside_core_network',
      );
    });

    test('go_router is allowed in core routing and route modules', () {
      expect(ruleFor('lib/core/routing/app_router.dart', goRouter), isNull);
      expect(
        ruleFor('lib/core/routing/adapters/go_router_adapter.dart', goRouter),
        isNull,
      );
      expect(
        ruleFor('lib/features/auth/routing/auth_routes.dart', goRouter),
        isNull,
      );
    });

    test('go_router outside those places is a violation', () {
      expect(
        ruleFor(
          'lib/features/auth/presentation/screens/login_screen.dart',
          goRouter,
        ),
        'go_router_outside_routing',
      );
      // A file inside a feature's routing/ folder that is not a designated
      // *_routes.dart module gets no exemption.
      expect(
        ruleFor('lib/features/auth/routing/auth_guard.dart', goRouter),
        'go_router_outside_routing',
      );
      expect(
        ruleFor('lib/shared/widgets/app_link.dart', goRouter),
        'go_router_outside_routing',
      );
    });

    test('lib/core importing lib/features is a violation', () {
      expect(
        ruleFor(
          'lib/core/di/providers.dart',
          pkg('features/auth/di/auth_providers.dart'),
        ),
        'core_imports_feature',
      );
      expect(
        ruleFor(
          'lib/core/feature_flags/feature_flags_manager.dart',
          pkg('features/feature_flags/domain/entities/feature_flag.dart'),
        ),
        'core_imports_feature',
      );
    });

    test('the route registry seam is permanently allowed', () {
      expect(
        ruleFor(kRoutesRegistry, pkg('features/auth/routing/auth_routes.dart')),
        isNull,
      );
    });
  });

  group('strippable sample paths', () {
    test('cover what tool/strip_sample_features.dart deletes', () {
      expect(
        isStrippableSamplePath(
          'lib/features/tasks/presentation/screens/task_detail_screen.dart',
        ),
        isTrue,
      );
      expect(
        isStrippableSamplePath(
          'lib/core/feature_flags/feature_flags_manager.dart',
        ),
        isTrue,
      );
    });

    test('do not cover files no strip variant removes', () {
      expect(
        isStrippableSamplePath('lib/core/errors/dio_exception_mapper.dart'),
        isFalse,
      );
      expect(
        isStrippableSamplePath('lib/core/di/providers.dart'),
        isFalse,
      );
      expect(
        isStrippableSamplePath(
          'lib/features/auth/presentation/screens/login_screen.dart',
        ),
        isFalse,
      );
    });
  });

  group('directive parsing', () {
    test('picks up import and export, with line numbers', () {
      const source = '''
// import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

export 'package:flutter_starter/features/auth/di/auth_providers.dart';
''';
      final directives = parseDirectives(source);
      expect(directives.map((d) => d.uri), <String>[
        'package:flutter/material.dart',
        'package:flutter_starter/features/auth/di/auth_providers.dart',
      ]);
      expect(directives.map((d) => d.line), <int>[2, 4]);
    });

    test('a commented-out directive is not a violation', () {
      expect(parseDirectives("  //import 'package:dio/dio.dart';"), isEmpty);
    });

    test('handles show/hide/as clauses and double quotes', () {
      const source = '''
import 'package:dio/dio.dart' show Dio;
import "package:go_router/go_router.dart" as go;
''';
      expect(parseDirectives(source).map((d) => d.uri), <String>[
        'package:dio/dio.dart',
        'package:go_router/go_router.dart',
      ]);
    });
  });
}
