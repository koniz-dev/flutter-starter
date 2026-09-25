// Taxonomy guard: every tracked surface in this repository maps to exactly one
// `epic:*` label.
//
// Why this exists. `CLAUDE.md` requires exactly one `epic:*` per issue, and the
// parallelism rule ("never two implementers in the same `epic:*`") keys on that
// label. A directory no epic covers therefore does not merely look untidy - it
// makes work unfileable, or files it under a near-miss label that silently
// widens or breaks the concurrency lock. Koniz-dev/flutter-starter#118 records
// four separate times that happened.
//
// The mapping is NOT duplicated here. `scripts/bootstrap-issue-labels.sh` is
// the single source of truth for the epic list and for the paths each epic
// claims; this tool shells out to `--list-map` and checks the tree against it.
// Anything that needs the mapping must read it the same way.
//
// Three failure directions, all fatal:
//   * a tracked surface no epic claims          -> a taxonomy gap
//   * a tracked surface two epics claim         -> an ambiguous lock
//   * a claimed path that is not in the tree    -> a stale claim
//
// The third direction is what stops the table outliving the directories it
// describes, the same way `test/tooling/import_rules_test.dart` refuses to keep
// an allowlist entry whose violation is gone.
//
// Run directly:
//   dart run tool/check_epic_coverage.dart
// It also runs as part of `flutter test` via test/tooling/epic_coverage_test.dart.

import 'dart:io';

/// One `epic:<slug> -> <path>` pair from `--list-map`.
class EpicClaim {
  const EpicClaim(this.epic, this.path);

  /// The full label name, for example `epic:core-di`.
  final String epic;

  /// A repository-relative path, forward slashes, no trailing slash.
  final String path;

  /// Stable one-line form, used in failure output and by the tests to compare
  /// claims. Deliberately not `==`/`hashCode`: `very_good_analysis` rejects
  /// those on a class that is not annotated `@immutable`, and `meta` is not a
  /// dependency of this package.
  @override
  String toString() => '$epic -> $path';
}

/// A surface with the wrong number of owners: zero (a gap) or more than one
/// (an ambiguous lock).
class CoverageFinding {
  const CoverageFinding(this.surface, this.epics);

  /// The repository-relative surface that failed the check.
  final String surface;

  /// The epics claiming it: empty for a gap, length >= 2 for an ambiguity.
  final List<String> epics;
}

/// The outcome of one coverage check.
class CoverageReport {
  const CoverageReport({
    required this.unclaimed,
    required this.ambiguous,
    required this.stale,
  });

  /// Surfaces no epic claims.
  final List<CoverageFinding> unclaimed;

  /// Surfaces more than one epic claims.
  final List<CoverageFinding> ambiguous;

  /// Claims whose path matches nothing in the tree.
  final List<EpicClaim> stale;

  bool get isClean => unclaimed.isEmpty && ambiguous.isEmpty && stale.isEmpty;

  /// A human-readable failure description. Empty when [isClean].
  String describe() {
    final buffer = StringBuffer();
    for (final finding in unclaimed) {
      buffer.writeln(
        '  no epic claims  ${finding.surface}',
      );
    }
    for (final finding in ambiguous) {
      buffer.writeln(
        '  ${finding.epics.length} epics claim  ${finding.surface}  '
        '(${finding.epics.join(', ')})',
      );
    }
    for (final claim in stale) {
      buffer.writeln('  claimed but absent from the tree  $claim');
    }
    return buffer.toString();
  }
}

/// Parses the output of `bootstrap-issue-labels.sh --list-map`.
///
/// Each non-empty line is `epic:<slug><TAB><path>`. Blank lines are ignored so
/// a trailing newline is not an error.
List<EpicClaim> parseEpicMap(String output) {
  final claims = <EpicClaim>[];
  for (final rawLine in output.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw FormatException('Malformed --list-map line: "$rawLine"');
    }
    claims.add(EpicClaim(parts[0], _normalise(parts[1])));
  }
  return claims;
}

String _normalise(String path) {
  var result = path.replaceAll(r'\', '/');
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

bool _isAtOrUnder(String path, String claimed) =>
    path == claimed || path.startsWith('$claimed/');

/// The set of surfaces the check applies to.
///
/// Walking starts at the repository root and descends into a directory only
/// when some claim points *inside* it. So `lib/` expands (epics claim
/// `lib/core/network` and friends) while `test/` does not (an epic claims
/// `test` whole). That keeps the surface list as coarse as the mapping allows
/// and as fine as it needs to be, with no second hardcoded list of directories
/// to drift.
List<String> surfacesOf(
  Iterable<String> trackedPaths,
  Iterable<String> claimedPaths,
) {
  final claims = claimedPaths.map(_normalise).toList();
  final tracked = trackedPaths.map(_normalise).where((p) => p.isNotEmpty);

  final surfaces = <String>{};
  void walk(String prefix) {
    final children = <String>{};
    for (final path in tracked) {
      if (prefix.isNotEmpty && !path.startsWith('$prefix/')) continue;
      final rest = prefix.isEmpty ? path : path.substring(prefix.length + 1);
      final segment = rest.split('/').first;
      if (segment.isEmpty) continue;
      children.add(prefix.isEmpty ? segment : '$prefix/$segment');
    }
    for (final child in children) {
      final expand = claims.any((c) => c.startsWith('$child/'));
      if (expand) {
        walk(child);
      } else {
        surfaces.add(child);
      }
    }
  }

  walk('');
  final sorted = surfaces.toList()..sort();
  return sorted;
}

/// Checks [trackedPaths] against [claims].
CoverageReport checkEpicCoverage({
  required Iterable<String> trackedPaths,
  required Iterable<EpicClaim> claims,
}) {
  final claimList = claims.toList();
  final tracked = trackedPaths
      .map(_normalise)
      .where((p) => p.isNotEmpty)
      .toList();
  final surfaces = surfacesOf(tracked, claimList.map((c) => c.path));

  final unclaimed = <CoverageFinding>[];
  final ambiguous = <CoverageFinding>[];
  for (final surface in surfaces) {
    final owners = <String>{
      for (final claim in claimList)
        if (_isAtOrUnder(surface, claim.path)) claim.epic,
    }.toList()..sort();
    if (owners.isEmpty) {
      unclaimed.add(CoverageFinding(surface, const []));
    } else if (owners.length > 1) {
      ambiguous.add(CoverageFinding(surface, owners));
    }
  }

  final stale = <EpicClaim>[
    for (final claim in claimList)
      if (!tracked.any((path) => _isAtOrUnder(path, claim.path))) claim,
  ];

  return CoverageReport(
    unclaimed: unclaimed,
    ambiguous: ambiguous,
    stale: stale,
  );
}

/// Reads the canonical mapping by running the bootstrap script.
///
/// Never re-type the table: this is the only supported way to obtain it.
List<EpicClaim> readCanonicalEpicMap({String repoRoot = '.'}) {
  final result = Process.runSync(
    'bash',
    <String>['scripts/bootstrap-issue-labels.sh', '--list-map'],
    workingDirectory: repoRoot,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'bootstrap-issue-labels.sh --list-map failed '
      '(exit ${result.exitCode}): ${result.stderr}',
    );
  }
  return parseEpicMap(result.stdout as String);
}

/// Lists the paths under version control, which is what "the tree" means here.
///
/// Two reasons this beats walking the filesystem. Build output, `.dart_tool/`
/// and other untracked noise is not a surface anyone files an issue against.
/// And the index survives `tool/strip_sample_features.dart`, which deletes the
/// sample slices from the working tree without touching version control - so
/// this guard keeps checking the real taxonomy under `strip-smoke.yml` instead
/// of reporting the stripped slices as claims gone stale.
List<String> readTrackedPaths({String repoRoot = '.'}) {
  final result = Process.runSync(
    'git',
    <String>['ls-files'],
    workingDirectory: repoRoot,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'listing tracked files failed (exit ${result.exitCode}): '
      '${result.stderr}',
    );
  }
  return (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

void main() {
  final report = checkEpicCoverage(
    trackedPaths: readTrackedPaths(),
    claims: readCanonicalEpicMap(),
  );
  if (report.isClean) {
    stdout.writeln('Epic coverage OK: every tracked surface maps to one epic.');
    return;
  }
  stderr
    ..writeln('Epic coverage check FAILED:')
    ..writeln(report.describe())
    ..writeln(
      'Fix the EPICS table in scripts/bootstrap-issue-labels.sh, then re-run '
      './scripts/bootstrap-issue-labels.sh so the live labels match.',
    );
  exitCode = 1;
}
