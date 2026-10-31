// Fails when the Android toolchain falls below what Flutter stable supports.
//
// Flutter only *warns* when Gradle, the Android Gradle Plugin or Kotlin is
// below its floor ("support ... will soon be dropped"), and CI pinned Java 17,
// so the project sat on Gradle 8.14 - which rejects the JDK 25 bundled with
// current Android Studio - while every check stayed green.
// This turns the warning into a failure.
//
// Reads:
//   android/gradle/wrapper/gradle-wrapper.properties   distributionUrl
//   android/settings.gradle.kts                         AGP and Kotlin plugins
//
// Usage:
//   dart run tool/check_android_toolchain.dart [root]
//
// `root` defaults to the current directory; tests point it at fixtures.
// Exits 0 when every version meets its floor, 1 otherwise.

import 'dart:io';

/// The floors, stated once. Flutter 3.47's own minimums, from
/// `DependencyVersionChecker.kt`; raise them when Flutter raises its own.
const Map<String, String> androidToolchainFloors = {
  'Gradle': '9.1.0',
  'Android Gradle Plugin': '9.0.1',
  'Kotlin': '2.3.20',
};

const String _wrapperPath = 'android/gradle/wrapper/gradle-wrapper.properties';
const String _settingsPath = 'android/settings.gradle.kts';

final RegExp _gradle = RegExp('distributionUrl=.*gradle-([0-9][0-9.]*)-');
final RegExp _agp = RegExp(
  r'''id\(\s*["']com\.android\.application["']\s*\)\s*version\s*["']([^"']+)["']''',
);
final RegExp _kotlin = RegExp(
  r'''id\(\s*["']org\.jetbrains\.kotlin\.android["']\s*\)\s*version\s*["']([^"']+)["']''',
);

/// Compares dotted numeric versions; missing parts count as 0, so
/// `8.14` < `9.1.0` and `9.1` == `9.1.0`. A non-numeric suffix such as
/// `-rc1` is ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
    for (final p in v.split('-').first.split('.')) int.tryParse(p) ?? 0,
  ];
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// The versions found under [root], keyed like [androidToolchainFloors]; a
/// version that could not be read maps to null.
Map<String, String?> readAndroidToolchain(Directory root) {
  String read(String relative) {
    final file = File('${root.path}/$relative');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  // Commented-out lines are skipped: a version kept in a comment (a previous
  // pin, a note) was read instead of the live declaration below it. A
  // .properties comment starts with `#` or `!`; Kotlin also has `/* */`.
  final wrapper = _uncommented(read(_wrapperPath), ['#', '!']);
  final settings = _uncommented(
    read(_settingsPath).replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ''),
    ['//'],
  );
  return {
    'Gradle': _gradle.firstMatch(wrapper)?.group(1),
    'Android Gradle Plugin': _agp.firstMatch(settings)?.group(1),
    'Kotlin': _kotlin.firstMatch(settings)?.group(1),
  };
}

/// [text] without the lines whose first non-blank characters are one of
/// [markers].
String _uncommented(String text, List<String> markers) => text
    .split('\n')
    .where((line) => !markers.any(line.trimLeft().startsWith))
    .join('\n');

/// One message per version that is unreadable or below its floor.
List<String> androidToolchainProblems(Directory root) {
  final found = readAndroidToolchain(root);
  final problems = <String>[];
  for (final MapEntry(key: tool, value: floor)
      in androidToolchainFloors.entries) {
    final version = found[tool];
    if (version == null) {
      final source = tool == 'Gradle' ? _wrapperPath : _settingsPath;
      problems.add('$tool: version not found in $source');
    } else if (compareVersions(version, floor) < 0) {
      problems.add(
        '$tool $version is below the floor $floor that Flutter stable '
        'supports',
      );
    }
  }
  return problems;
}

void main(List<String> args) {
  final root = Directory(args.isEmpty ? '.' : args.first);
  final found = readAndroidToolchain(root);
  for (final MapEntry(key: tool, value: floor)
      in androidToolchainFloors.entries) {
    stdout.writeln('$tool: ${found[tool] ?? '(not found)'} (floor $floor)');
  }
  final problems = androidToolchainProblems(root)..forEach(stderr.writeln);
  if (problems.isNotEmpty) {
    stderr.writeln('\n${problems.length} toolchain problem(s).');
    exit(1);
  }
  stdout.writeln('\nOK: the Android toolchain meets every floor.');
}
