// Fails when a GitHub Actions step runs an action that is not pinned to a
// commit SHA.
//
// A tag such as `@v2` can be moved to another commit by whoever controls the
// action's repository, and the deploy workflows hand that commit the project's
// store, hosting and signing secrets. A SHA cannot move. The `# vX.Y.Z`
// comment after it is what Dependabot's github-actions updates read and
// rewrite, so it is required too.
//
// Reads every workflow under `.github/workflows/`, every composite action
// (`action.yml` / `action.yaml`) under `.github/`, and every local action a
// workflow or action reaches through `uses: ./<path>`, wherever it lives; a
// `./<path>` with no `action.yml` / `action.yaml` is reported too. The files are parsed as
// YAML rather than matched line by line, so a `uses` key is found however it
// is spelled: block or flow mapping, quoted or not, `uses :` included.
//
// Usage:
//   dart run tool/check_action_pins.dart [root]
//
// `root` defaults to the current directory. Exits 0 when every action is
// pinned, 1 otherwise, printing `file:line: uses: <target>` for each.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One `uses` value: where it is, what it names, and the rest of its line
/// (where the version comment lives; YAML drops comments when parsing).
class ActionUse {
  const ActionUse(this.path, this.line, this.target, this.trailing);

  final String path;

  /// 1-based.
  final int line;
  final String target;
  final String trailing;

  @override
  String toString() => '$path:$line: uses: $target';
}

/// `owner/repo[/path]@<40 hex>`
final RegExp _shaRef = RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$');

/// `# v1.2.3` as the line's YAML comment: after the `uses` value only the
/// brackets and commas that close its flow collection may come before it, so
/// a `#` inside another key's string (`name: "x # v1.0"`) is not a comment.
final RegExp _versionComment = RegExp(
  r'^[\s,}\]]*\s#\s*v?\d+(\.\d+){1,2}\S*\s*$',
);

/// Exempt: actions in this repository, and container images by digest.
bool _exempt(String target) =>
    target.startsWith('./') ||
    (target.startsWith('docker://') && target.contains('@sha256:'));

/// Every `uses` key in [source], at any depth.
List<ActionUse> actionUses(String path, String source) {
  final lines = source.split('\n');
  final found = <ActionUse>[];
  void walk(YamlNode node) {
    if (node is YamlMap) {
      for (final MapEntry(:key, :value) in node.nodes.entries) {
        if (key is YamlScalar &&
            key.value == 'uses' &&
            value is YamlScalar &&
            value.value is String) {
          final end = value.span.end;
          found.add(
            ActionUse(
              path,
              value.span.start.line + 1,
              value.value as String,
              lines[end.line].substring(end.column),
            ),
          );
        } else {
          walk(value);
        }
      }
    } else if (node is YamlList) {
      node.nodes.forEach(walk);
    }
  }

  walk(loadYamlNode(source, sourceUrl: Uri.file(path)));
  return found;
}

/// Each `uses` in [source] that is neither exempt nor pinned to a SHA with
/// its version comment.
List<ActionUse> unpinnedUses(String path, String source) => [
  for (final use in actionUses(path, source))
    if (!_exempt(use.target) &&
        !(_shaRef.hasMatch(use.target) &&
            _versionComment.hasMatch(use.trailing)))
      use,
];

/// The workflows and composite actions under [root]'s `.github/`, plus every
/// local action (`uses: ./path`) they reach, wherever it lives, sorted.
List<File> actionFiles(Directory root) => _scan(root).files;

/// Each `uses: ./path` whose directory has no `action.yml` / `action.yaml`.
/// GitHub cannot run it, and the check cannot see what it would run.
List<ActionUse> missingLocalActions(Directory root) => _scan(root).missing;

({List<File> files, List<ActionUse> missing}) _scan(Directory root) {
  final github = Directory('${root.path}/.github');
  final queue = [
    if (github.existsSync())
      for (final entity in github.listSync(recursive: true))
        if (entity is File && _isActionFile(entity.path)) entity,
  ];
  final seen = <String, File>{};
  final missing = <ActionUse>[];
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (seen.putIfAbsent(p.normalize(file.absolute.path), () => file) != file) {
      continue;
    }
    for (final use in actionUses(file.path, file.readAsStringSync())) {
      if (!use.target.startsWith('./')) continue;
      final dir = Directory(p.join(root.path, use.target.substring(2)));
      final action = dir.existsSync()
          ? dir
                .listSync()
                .whereType<File>()
                .where((f) => _isActionName(p.basename(f.path)))
                .firstOrNull
          : null;
      if (action == null) {
        missing.add(use);
      } else {
        queue.add(action);
      }
    }
  }
  final files = seen.values.toList()..sort((a, b) => a.path.compareTo(b.path));
  return (files: files, missing: missing);
}

/// Every problem under [root], as `file:line: ...` lines: unpinned actions,
/// then local actions that do not exist.
List<String> checkActionPins(Directory root) => [
  for (final f in actionFiles(root))
    for (final use in unpinnedUses(f.path, f.readAsStringSync())) '$use',
  for (final use in missingLocalActions(root))
    '$use (no action.yml or action.yaml there)',
];

/// Names compare case-insensitively: a case-insensitive file system (a macOS
/// runner) loads `Action.yml` as `action.yml`, so the check reads it too.
bool _isActionName(String name) =>
    const {'action.yml', 'action.yaml'}.contains(name.toLowerCase());

bool _isActionFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final name = normalized.split('/').last;
  if (_isActionName(name)) return true;
  final lower = name.toLowerCase();
  return normalized.contains('/.github/workflows/') &&
      (lower.endsWith('.yml') || lower.endsWith('.yaml'));
}

void main(List<String> args) {
  final root = Directory(args.isEmpty ? '.' : args.first);
  final files = actionFiles(root);
  if (files.isEmpty) {
    stderr.writeln('No workflows found under ${root.path}/.github.');
    exit(1);
  }
  final problems = checkActionPins(root);
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    stderr.writeln(
      'Pin each action to the commit of a release, with the release as a '
      'comment: uses: owner/repo@<40-hex sha> # vX.Y.Z',
    );
    exit(1);
  }
  stdout.writeln('${files.length} files, every action pinned.');
}
