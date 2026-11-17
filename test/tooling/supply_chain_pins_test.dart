// Two downloads ran unpinned: the Gradle wrapper fetched its distribution
// without a checksum, so a tampered or truncated zip was used as is, and CI
// activated whatever mason_cli was latest. Both are pinned now; these keep
// the pins from being dropped on the next bump.

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
