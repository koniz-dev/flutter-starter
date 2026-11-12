// The Flutter channel floats on stable, so a new stable can raise its Android
// toolchain floors with no change in this repository. The job that builds a
// debug APK on the current stable ran only on a PR touching android/, so when
// Flutter 3.50 raised the floors the Android build stayed broken on main
// until a PR happened to touch the workflow. It now also runs weekly, in the
// template repository only.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final file = File('.github/workflows/build.yml');

  test('the Android floor job runs on a weekly schedule', () {
    if (!file.existsSync()) {
      markTestSkipped('build.yml is not in this tree');
      return;
    }
    final workflow = loadYaml(file.readAsStringSync()) as YamlMap;
    final schedule = (workflow['on'] as YamlMap)['schedule'] as YamlList?;

    expect(schedule, isNotNull);
    expect(
      '${(schedule!.single as YamlMap)['cron']}',
      // minute hour * * weekday: once a week.
      matches(RegExp(r'^\d+ \d+ \* \* [0-6]$')),
    );
  });

  test('only the floor job runs on the schedule, and only in the template', () {
    if (!file.existsSync()) {
      markTestSkipped('build.yml is not in this tree');
      return;
    }
    final jobs =
        (loadYaml(file.readAsStringSync()) as YamlMap)['jobs'] as YamlMap;
    final scheduled = {
      for (final job in jobs.entries)
        if ('${(job.value as YamlMap)['if']}'.contains("'schedule'"))
          '${job.key}': '${(job.value as YamlMap)['if']}',
    };

    expect(scheduled.keys, ['android-jdk25']);
    expect(
      scheduled['android-jdk25'],
      contains(
        "(github.event_name == 'schedule' && "
        'github.event.repository.is_template)',
      ),
    );
    // Every other job is guarded by a dispatch input, which a scheduled run
    // does not have: it must not start a release build nobody asked for.
    for (final job in jobs.entries.where((j) => j.key != 'android-jdk25')) {
      expect(
        '${(job.value as YamlMap)['if']}',
        startsWith('inputs.platform =='),
        reason: '${job.key}',
      );
    }
  });
}
