// Two downloads ran unpinned: the Gradle wrapper fetched its distribution
// without a checksum, so a tampered or truncated zip was used as is, and CI
// activated whatever mason_cli was latest - as did the docs that tell an
// adopter to install it. All are pinned now; these keep the pins from being
// dropped or drifting apart on the next bump.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Gradle wrapper pins the distribution checksum', () {
    final properties = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('#')).toList();

    expect(
      properties.where((l) => l.startsWith('distributionUrl=')),
      hasLength(1),
    );
    expect(
      properties.where(
        (l) => RegExp(r'^distributionSha256Sum=[0-9a-f]{64}$').hasMatch(l),
      ),
      hasLength(1),
    );
  });

  test('every workflow that activates a pub CLI names its version', () {
    final unpinned = [
      for (final file in Directory('.github/workflows').listSync())
        if (file is File && file.path.endsWith('.yml'))
          for (final line in file.readAsLinesSync())
            if (RegExp(r'pub global activate \S+\s*$').hasMatch(line))
              '${file.path}: ${line.trim()}',
    ];

    expect(unpinned, isEmpty);
  });

  test('docs activate the mason_cli version the workflows pin', () {
    final activate = RegExp(r'activate mason_cli(?: ([0-9][^\s`)]*))?');
    final pinned = {
      for (final file in Directory('.github/workflows').listSync())
        if (file is File && file.path.endsWith('.yml'))
          for (final m in activate.allMatches(file.readAsStringSync()))
            m.group(1),
    };
    final docs = (Process.runSync('git', ['ls-files', '*.md']).stdout as String)
        .split('\n')
        // A tracked file deleted but not yet committed (the strip tool's
        // --remove-bricks leaves it so) has nothing left to check.
        .where((p) => p.isNotEmpty && File(p).existsSync());
    final mismatched = [
      for (final path in docs)
        for (final m in activate.allMatches(File(path).readAsStringSync()))
          if (pinned.isEmpty
              ? m.group(1) == null
              : pinned.length > 1 || m.group(1) != pinned.single)
            '$path: ${m.group(0)}',
    ];

    expect(mismatched, isEmpty, reason: 'workflows pin $pinned');
  });

  // Xcode writes the workspace's Package.resolved on the first iOS or macOS
  // build; untracked, it dirtied a fresh clone's tree. It is committed, and
  // must pin what the project's copy pins.
  for (final platform in ['ios', 'macos']) {
    test('$platform: the workspace Package.resolved matches the project', () {
      const path = 'xcshareddata/swiftpm/Package.resolved';
      final workspace = File('$platform/Runner.xcworkspace/$path');
      final project = File(
        '$platform/Runner.xcodeproj/project.xcworkspace/$path',
      );

      expect(workspace.existsSync(), isTrue, reason: workspace.path);
      expect(workspace.readAsStringSync(), project.readAsStringSync());
    });
  }
}
