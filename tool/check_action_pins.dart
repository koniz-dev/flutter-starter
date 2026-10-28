// Fails when a GitHub Actions step runs an action that is not pinned to a
// commit SHA, or (with --verify-tags) whose SHA is not the commit its version
// comment names.
//
// A tag such as `@v2` can be moved to another commit by whoever controls the
// action's repository, and the deploy workflows hand that commit the project's
// store, hosting and signing secrets. A SHA cannot move. The `# vX.Y.Z`
// comment after it is what Dependabot's github-actions updates read and
// rewrite, so it is required too. And it is checked: GitHub runs
// `owner/repo@<sha>` for any commit in the repository's fork network,
// including one pushed only to a fork, so a well-formed pin with a plausible
// comment could still run someone else's code.
//
// Reads every workflow under `.github/workflows/`, every composite action
// (`action.yml` / `action.yaml`) under `.github/`, and every local action a
// workflow or action reaches through `uses: ./<path>`, wherever it lives; a
// `./<path>` with no `action.yml` / `action.yaml` is reported too. The files
// are parsed as YAML rather than matched line by line, so a `uses` key is
// found however it is spelled (block or flow mapping, quoted or not, escaped)
// and text in another key is never taken for a pin.
//
// Usage:
//   dart run tool/check_action_pins.dart [root]
//   dart run tool/check_action_pins.dart --verify-tags [root]
//
// `root` defaults to the current directory. Without a flag it works offline
// and exits 0 when every action is pinned, 1 otherwise, printing
// `file:line: uses: <target>` for each. --verify-tags then resolves each
// version comment's tag in `owner/repo` through `gh api` (annotated tags
// peeled) and exits 1 on a mismatch or a missing tag, 2 when the API could not
// be asked. It needs `gh` authenticated (in Actions:
// `GH_TOKEN: ${{ github.token }}`).

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

/// `owner/repo` and the SHA of a pinned target.
final RegExp _pinParts = RegExp(r'^([\w.-]+/[\w.-]+)[\w./-]*@([0-9a-f]{40})$');

/// `# v1.2.3` as the line's YAML comment: after the `uses` value only the
/// brackets and commas that close its flow collection may come before it, so
/// a `#` inside another key's string (`name: "x # v1.0"`) is not a comment.
/// Group 1 is the version.
///
/// The version is an allowlist, not "anything after `#`": it becomes a path
/// in a GitHub API call, where `..` or `?` would point it at another
/// repository's tag.
final RegExp _versionComment = RegExp(
  r'^[\s,}\]]*\s#\s*'
  r'(v?\d+(?:\.\d+){1,2}(?:[-+][0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?)\s*$',
);

/// The text of a `#` comment in the rest of a line, when there is one.
final RegExp _anyComment = RegExp(r'\s#\s*(.*?)\s*$');

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
    for (final use in unpinnedUses(f.path, f.readAsStringSync()))
      _describe(use),
  for (final use in missingLocalActions(root))
    '$use (no action.yml or action.yaml there)',
];

/// [use] as a problem line, saying why when it is pinned to a SHA but its
/// comment is not a release tag.
String _describe(ActionUse use) {
  final comment = _anyComment.firstMatch(use.trailing)?.group(1);
  if (_shaRef.hasMatch(use.target) && comment != null) {
    return '$use: version comment "$comment" is not a release tag (vX.Y.Z)';
  }
  return '$use';
}

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

/// Resolves the commit [tag] names in [repo] (`owner/repo`), or null when
/// the tag does not exist. Throws [TagLookupException] when it cannot tell.
typedef TagResolver = String? Function(String repo, String tag);

/// The API could not be asked, so neither a match nor a mismatch is known.
class TagLookupException implements Exception {
  const TagLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A [TagResolver] over `gh api`, following annotated tags to their commit.
/// [gh] is the executable to run; tests point it at a fake.
TagResolver ghTagResolver({String gh = 'gh'}) => (repo, tag) {
  (String, String)? object(String path) {
    final result = Process.runSync(gh, [
      'api',
      path,
      '--jq',
      '.object.type + " " + .object.sha',
    ]);
    if (result.exitCode != 0) {
      final output = '${result.stdout}${result.stderr}'.trim();
      if (output.contains('HTTP 404') || output.contains('Not Found')) {
        return null;
      }
      throw TagLookupException('GitHub API error for $path: $output');
    }
    final parts = (result.stdout as String).trim().split(' ');
    return parts.length == 2 ? (parts[0], parts[1]) : null;
  }

  var found = object('repos/$repo/git/ref/tags/$tag');
  while (found != null && found.$1 == 'tag') {
    found = object('repos/$repo/git/tags/${found.$2}');
  }
  return found?.$1 == 'commit' ? found!.$2 : null;
};

/// Checks every non-exempt `uses` under [root] against the commit its
/// version comment's tag names, as `file:line: ...` problems. Every such
/// `uses` is either verified or reported, so a pin the check cannot read is
/// never a silent pass. Each `owner/repo@tag` is resolved once.
({List<String> problems, int verified}) verifyTags(
  Directory root,
  TagResolver resolve,
) {
  final resolved = <String, String?>{};
  final problems = <String>[];
  var verified = 0;
  for (final file in actionFiles(root)) {
    for (final use in actionUses(file.path, file.readAsStringSync())) {
      if (_exempt(use.target)) continue;
      final pin = _pinParts.firstMatch(use.target);
      final version = _versionComment.firstMatch(use.trailing)?.group(1);
      final at = '${use.path}:${use.line}';
      if (pin == null || version == null) {
        problems.add('$at: uses: ${use.target} is not a pinned release');
        continue;
      }
      final (repo, sha) = (pin.group(1)!, pin.group(2)!);
      final real = resolved.putIfAbsent(
        '$repo@$version',
        () => resolve(repo, version),
      );
      if (real == null) {
        problems.add('$at: $repo has no tag $version; the pin is $sha');
      } else if (real != sha) {
        problems.add('$at: $repo $version is $real, but the pin is $sha');
      } else {
        verified++;
      }
    }
  }
  return (problems: problems, verified: verified);
}

void main(List<String> args) {
  final verify = args.contains('--verify-tags');
  final rest = args.where((a) => a != '--verify-tags').toList();
  final root = Directory(rest.isEmpty ? '.' : rest.first);
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
  if (!verify) {
    stdout.writeln('${files.length} files, every action pinned.');
    return;
  }
  final ({List<String> problems, int verified}) result;
  try {
    result = verifyTags(root, ghTagResolver());
  } on TagLookupException catch (e) {
    stderr.writeln(e);
    exit(2);
  }
  if (result.problems.isNotEmpty) {
    result.problems.forEach(stderr.writeln);
    stderr.writeln(
      '${result.problems.length} pins are not the commit their version '
      'comment names.',
    );
    exit(1);
  }
  stdout.writeln(
    '${result.verified} pins in ${files.length} files match their version '
    'comment.',
  );
}
