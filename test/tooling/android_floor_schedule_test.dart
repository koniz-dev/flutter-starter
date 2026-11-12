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
    // The whole condition, whitespace collapsed: a substring check would
    // pass a guard followed by `&& false`, or a job that runs on anything
    // but a dispatch.
    final conditions = {
      for (final job in jobs.entries)
        '${job.key}': '${(job.value as YamlMap)['if']}'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
    };

    // A project that wants the weekly run in its own repository drops the
    // `is_template` clause from the workflow and from this value.
    expect(conditions, {
      'android-jdk25':
          "github.event_name == 'pull_request' || "
          "(github.event_name == 'schedule' && "
          'github.event.repository.is_template) || '
          "inputs.platform == 'all' || inputs.platform == 'android'",
      // Guarded by a dispatch input, which a scheduled run does not have: it
      // must not start a release build nobody asked for.
      'build-android':
          "inputs.platform == 'all' || inputs.platform == 'android'",
      'build-ios': "inputs.platform == 'all' || inputs.platform == 'ios'",
      'build-web': "inputs.platform == 'all' || inputs.platform == 'web'",
    });
  });
}
