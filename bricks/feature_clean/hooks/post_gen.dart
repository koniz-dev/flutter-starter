import 'dart:io';

import 'package:mason/mason.dart';

/// Sorts and formats what the brick just generated.
///
/// The templates write imports in the order that is sorted for the package
/// name `flutter_starter`. Both rename paths - `mason make
/// flutter_starter_setup` and fork-and-customize Option B - rewrite that name
/// inside these templates, and a name that sorts after `flutter_test`
/// (`my_app`) or before `flutter_riverpod` (`app`) then trips
/// `directives_ordering` in every generated file. So the analyzer sorts them,
/// exactly as `scripts/dev/create_feature.sh` does,
/// and `dart format` wraps them.
Future<void> run(HookContext context) async {
  // Mason runs hooks with the generation output folder as the working
  // directory; HookContext has no target path API (mason ^0.1.2+).
  final root = Directory.current.path;
  final feature = context.vars['feature_name'] as String;
  final dirs = [
    'lib/features/$feature',
    if (context.vars['include_tests'] == true) 'test/features/$feature',
  ].where((d) => Directory('$root/$d').existsSync()).toList();

  Future<void> dart(List<String> args) async {
    final result = await Process.run(
      'dart',
      args,
      workingDirectory: root,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      context.logger.warn(
        '`dart ${args.join(' ')}` exited ${result.exitCode}; run it yourself '
        'before flutter analyze.\n${result.stderr}',
      );
    }
  }

  for (final dir in dirs) {
    await dart(['fix', '--apply', '--code=directives_ordering', dir]);
  }
  if (dirs.isNotEmpty) await dart(['format', ...dirs]);
}
