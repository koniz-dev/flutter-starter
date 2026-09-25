// Taxonomy guard tests for tool/check_epic_coverage.dart.
//
// Two halves, both needed:
//   * counterfactuals on synthetic input, so a green run means the checker can
//     actually fail rather than that it never looks at anything;
//   * one test against the real tree and the real
//     `scripts/bootstrap-issue-labels.sh --list-map`, which is the check that
//     keeps koniz-dev/flutter-starter#118 from recurring.
//
// The real-tree test shells out to `bash` and to the version control CLI, so it
// is skipped on Windows. CI runs on ubuntu-latest.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: tool/ is not part of the published library, so there is no
// package: URI for it. test/ and tool/ are both outside lib/, which is what
// avoid_relative_lib_imports cares about.
import '../../tool/check_epic_coverage.dart';

void main() {
  group('parseEpicMap', () {
    test('parses tab-separated epic/path pairs and ignores blank lines', () {
      final claims = parseEpicMap('epic:a\tlib/core/a\n\nepic:b\tlib/core/b\n');

      expect(claims.map((c) => c.toString()), <String>[
        'epic:a -> lib/core/a',
        'epic:b -> lib/core/b',
      ]);
    });

    test(
      'strips a trailing slash so lib/core/a/ and lib/core/a are one path',
      () {
        expect(parseEpicMap('epic:a\tlib/core/a/\n').single.path, 'lib/core/a');
      },
    );

    test('rejects a line that is not exactly epic and path', () {
      expect(() => parseEpicMap('epic:a lib/core/a\n'), throwsFormatException);
      expect(
        () => parseEpicMap('epic:a\tlib/core/a\textra\n'),
        throwsFormatException,
      );
    });
  });

  group('surfacesOf', () {
    test('descends only into directories a claim points inside', () {
      final surfaces = surfacesOf(
        <String>[
          'lib/core/network/api_client.dart',
          'lib/core/utils/date_utils.dart',
          'lib/main.dart',
          'test/core/network/api_client_test.dart',
        ],
        <String>['lib/core/network', 'lib/core/utils', 'lib/main.dart', 'test'],
      );

      // `test` stays whole because nothing is claimed inside it; `lib` splits
      // because the claims are deeper.
      expect(surfaces, <String>[
        'lib/core/network',
        'lib/core/utils',
        'lib/main.dart',
        'test',
      ]);
    });
  });

  group('checkEpicCoverage counterfactuals', () {
    test('flags a directory no epic claims', () {
      final report = checkEpicCoverage(
        trackedPaths: <String>[
          'lib/core/network/api_client.dart',
          'lib/core/orphan/thing.dart',
        ],
        claims: <EpicClaim>[
          const EpicClaim('epic:core-network', 'lib/core/network'),
        ],
      );

      expect(report.isClean, isFalse);
      expect(report.unclaimed.single.surface, 'lib/core/orphan');
      expect(report.describe(), contains('no epic claims  lib/core/orphan'));
    });

    test('flags a directory two epics claim', () {
      final report = checkEpicCoverage(
        trackedPaths: <String>[
          'lib/core/network/api_client.dart',
          'lib/core/utils/x.dart',
        ],
        claims: <EpicClaim>[
          const EpicClaim('epic:core-network', 'lib/core/network'),
          const EpicClaim('epic:core-foundation', 'lib/core'),
          const EpicClaim('epic:core-foundation', 'lib/core/utils'),
        ],
      );

      expect(report.isClean, isFalse);
      expect(report.ambiguous.single.surface, 'lib/core/network');
      expect(
        report.ambiguous.single.epics,
        <String>['epic:core-foundation', 'epic:core-network'],
      );
    });

    test('flags a claim whose path is no longer in the tree', () {
      final report = checkEpicCoverage(
        trackedPaths: <String>['lib/core/network/api_client.dart'],
        claims: <EpicClaim>[
          const EpicClaim('epic:core-network', 'lib/core/network'),
          const EpicClaim('epic:gone', 'lib/core/removed'),
        ],
      );

      expect(report.isClean, isFalse);
      expect(report.stale.single.path, 'lib/core/removed');
      expect(report.describe(), contains('claimed but absent'));
    });

    test('a fully mapped tree is clean', () {
      final report = checkEpicCoverage(
        trackedPaths: <String>['lib/main.dart', 'docs/readme.md'],
        claims: <EpicClaim>[
          const EpicClaim('epic:app-shell', 'lib/main.dart'),
          const EpicClaim('epic:docs', 'docs'),
        ],
      );

      expect(report.isClean, isTrue);
      expect(report.describe(), isEmpty);
    });
  });

  group('the real repository', () {
    late List<EpicClaim> claims;
    late List<String> tracked;

    setUpAll(() {
      claims = readCanonicalEpicMap();
      tracked = readTrackedPaths();
    });

    test('every tracked surface maps to exactly one epic', () {
      final report = checkEpicCoverage(trackedPaths: tracked, claims: claims);

      expect(
        report.isClean,
        isTrue,
        reason:
            'Epic coverage check failed:\n${report.describe()}\n'
            'Fix the EPICS table in scripts/bootstrap-issue-labels.sh.',
      );
    });

    test('the surface list is non-trivial and includes the #118 gaps', () {
      final surfaces = surfacesOf(tracked, claims.map((c) => c.path));

      // Guards against a vacuous pass: if the walk ever stopped producing
      // surfaces, every check above would go green having inspected nothing.
      expect(surfaces.length, greaterThan(30));
      expect(
        surfaces,
        containsAll(<String>[
          'lib/core/di',
          'lib/core/contracts',
          'lib/core/utils',
          'lib/core/errors',
          'lib/core/logging',
          'lib/core/performance',
          'lib/features/feature_flags',
          'android',
          'ios',
          'macos',
          'web',
          'fastlane',
        ]),
      );
    });

    test('every epic in --list-epics claims at least one path', () {
      final listed = Process.runSync(
        'bash',
        <String>['scripts/bootstrap-issue-labels.sh', '--list-epics'],
      );
      expect(listed.exitCode, 0, reason: listed.stderr.toString());

      final slugs = (listed.stdout as String)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toSet();
      final claiming = claims.map((c) => c.epic).toSet();

      expect(slugs, isNotEmpty);
      expect(
        slugs.difference(claiming),
        isEmpty,
        reason:
            'These epics claim no path, so no diff can be attributed to '
            'them. Give each one a path in the EPICS table.',
      );
      expect(
        claiming.difference(slugs),
        isEmpty,
        reason: '--list-map named an epic --list-epics does not.',
      );
    });
  }, skip: Platform.isWindows ? 'needs bash; CI runs on ubuntu' : null);
}
