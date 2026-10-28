// Fails when a GitHub Actions step runs an action that is not pinned to a
// commit SHA.
//
// A tag such as `@v2` can be moved to another commit by whoever controls the
// action's repository, and the deploy workflows hand that commit the project's
// store, hosting and signing secrets. A SHA cannot move. The `# vX.Y.Z`
// comment after it is what Dependabot's github-actions updates read and
// rewrite, so it is required too.
//
// Reads every workflow under `.github/workflows/` and every composite action
// (`action.yml` / `action.yaml`) under `.github/`. The files are parsed as
// YAML rather than matched line by line, so a `uses` key is found however it
// is spelled: block or flow mapping, quoted or not, `uses :` included.
//
// Usage:
//   dart run tool/check_action_pins.dart [root]
//
// `root` defaults to the current directory. Exits 0 when every action is
// pinned, 1 otherwise, printing `file:line: uses: <target>` for each.

import 'dart:io';

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

/// `# v1.2.3` at the end of the line, after anything that closes a flow
/// collection.
final RegExp _versionComment = RegExp(r'#\s*v?\d+(\.\d+){1,2}\S*\s*$');

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

/// The workflows and composite actions under [root]'s `.github/`, sorted.
List<File> actionFiles(Directory root) {
  final github = Directory('${root.path}/.github');
  if (!github.existsSync()) return [];
  final files = [
    for (final entity in github.listSync(recursive: true))
      if (entity is File && _isActionFile(entity.path)) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

bool _isActionFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final name = normalized.split('/').last;
  if (name == 'action.yml' || name == 'action.yaml') return true;
  return normalized.contains('/.github/workflows/') &&
      (name.endsWith('.yml') || name.endsWith('.yaml'));
}

void main(List<String> args) {
  final root = Directory(args.isEmpty ? '.' : args.first);
  final files = actionFiles(root);
  if (files.isEmpty) {
    stderr.writeln('No workflows found under ${root.path}/.github.');
    exit(1);
  }
  final unpinned = [
    for (final f in files) ...unpinnedUses(f.path, f.readAsStringSync()),
  ];
  if (unpinned.isNotEmpty) {
    unpinned.forEach(stderr.writeln);
    stderr.writeln(
      'Pin each action to the commit of a release, with the release as a '
      'comment: uses: owner/repo@<40-hex sha> # vX.Y.Z',
    );
    exit(1);
  }
  stdout.writeln('${files.length} files, every action pinned.');
}
