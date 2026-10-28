// Kept markdown must not name a sample feature's symbols outside a strip
// marker.
//
// `--remove-feature-flags` used to delete `docs/features/feature-flags.md` and
// leave `docs/guides/configuration.md` documenting `LocalFeatureFlagsService`
// and the `/feature-flags-debug` route in a tree that had neither. The rule:
// every mention of a sample's public symbol, in a code span or a fenced block,
// sits inside a `<!-- strip:<tag> ... -->` region or on a marked line, so
// the strip removes it with the sample.
//
// The same test runs in the full tree and in every strip variant. With the
// sample present its markers are still there and are skipped; with it
// stripped they are gone, and the symbols come from `git show HEAD:`, which
// still has the source the working tree no longer does.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _Sample {
  const _Sample(this.tag, this.dirs, this.deletedDocs, this.extraTokens);

  /// Marker tag, as in `<!-- strip:<tag> start -->`.
  final String tag;

  /// Source directories the strip deletes.
  final List<String> dirs;

  /// Markdown files the strip deletes outright; nothing in them is checked.
  final List<String> deletedDocs;

  /// Names that are not declarations but are as specific to the sample.
  final List<String> extraTokens;
}

const _samples = [
  _Sample(
    'feature-flags',
    ['lib/features/feature_flags'],
    ['docs/features/feature-flags.md'],
    ['/feature-flags-debug'],
  ),
  _Sample(
    'tasks',
    ['lib/features/tasks'],
    ['docs/features/tasks.md'],
    // Declared in lib/core/routing/app_routes.dart, which the strip keeps
    // and rewrites, so the declaration scan does not see them as the
    // sample's.
    ['AppRoutes.task', 'taskDetailName', "'/tasks"],
  ),
];

/// Not checked: archives of what happened, which name what existed then.
bool _isHistory(String path) =>
    path == 'CHANGELOG.md' || path.startsWith('docs/architecture/adr/');

final RegExp _declaration = RegExp(
  r'^(?:(?:abstract|sealed|final|base|interface)\s+)*'
  r'(?:class|enum|mixin|extension|typedef)\s+([A-Z]\w*)'
  r'|^(?:final|const)\s+(?:\w+\s+)?([a-z]\w*Provider)\b'
  r'|^\w[\w<>?, ]*\s+([a-z]\w*Provider)\s*\(',
  multiLine: true,
);

Set<String> _declaredIn(Iterable<String> sources) => {
  for (final source in sources)
    for (final m in _declaration.allMatches(source))
      [m.group(1), m.group(2), m.group(3)].firstWhere((g) => g != null)!,
}..removeWhere((name) => name.startsWith('_'));

bool _isSource(String path) =>
    path.endsWith('.dart') &&
    !path.endsWith('.g.dart') &&
    !path.endsWith('.freezed.dart');

/// The sample's sources from the working tree, or from HEAD once stripped.
/// Null when neither has them (a fork that committed the strip).
List<String>? _sampleSources(_Sample sample) {
  final onDisk = [
    for (final dir
        in sample.dirs.map(Directory.new).where((d) => d.existsSync()))
      for (final f in dir.listSync(recursive: true).whereType<File>())
        if (_isSource(f.path)) f.readAsStringSync(),
  ];
  if (onDisk.isNotEmpty) return onDisk;

  final listed = Process.runSync('git', [
    'ls-tree',
    '-r',
    '--name-only',
    'HEAD',
    '--',
    ...sample.dirs,
  ]);
  if (listed.exitCode != 0) return null;
  final paths = (listed.stdout as String).split('\n').where(_isSource).toList();
  if (paths.isEmpty) return null;
  return [
    for (final path in paths)
      Process.runSync('git', ['show', 'HEAD:$path']).stdout as String,
  ];
}

/// Names declared by the sample and by nothing the strip keeps.
Set<String> _sampleSymbols(_Sample sample, List<String> sources) {
  final kept = [
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>())
      if (_isSource(f.path) &&
          !sample.dirs.any((d) => f.path.startsWith('$d/')))
        f.readAsStringSync(),
  ];
  return _declaredIn(sources).difference(_declaredIn(kept));
}

List<File> _markdown() {
  final found = <File>[];
  void walk(Directory dir) {
    for (final e in dir.listSync(followLinks: false)) {
      final name = e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (e is Directory) {
        if (const {
          '.git',
          '.dart_tool',
          'build',
          'node_modules',
        }.contains(name)) {
          continue;
        }
        walk(e);
      } else if (e is File && e.path.endsWith('.md')) {
        found.add(e);
      }
    }
  }

  walk(Directory.current);
  return found;
}

/// Lines of [source] the strip of [tag] would keep, with their numbers, and
/// whether each is inside a fenced code block.
Iterable<(int, String, bool)> _unmarkedLines(String source, String tag) sync* {
  var inRegion = false;
  var inFence = false;
  var number = 0;
  for (final line in source.split('\n')) {
    number++;
    final trimmed = line.trim();
    if (trimmed == '<!-- strip:$tag start -->') {
      inRegion = true;
      continue;
    }
    if (trimmed == '<!-- strip:$tag end -->') {
      inRegion = false;
      continue;
    }
    if (RegExp('^(`{3,}|~{3,})').hasMatch(trimmed)) {
      inFence = !inFence;
      continue;
    }
    if (inRegion || line.contains('<!-- strip:$tag line -->')) continue;
    // Symbol and signature directives go with the files they name.
    if (trimmed.startsWith('<!-- symbol:') ||
        trimmed.startsWith('<!-- signature:')) {
      continue;
    }
    yield (number, line, inFence);
  }
}

void main() {
  final root = Directory.current.path;

  for (final sample in _samples) {
    final sources = _sampleSources(sample);

    test(
      'criteria 2-3: kept markdown names no ${sample.tag} symbol outside a '
      'strip:${sample.tag} marker',
      () {
        final symbols = _sampleSymbols(sample, sources!);
        expect(symbols, isNotEmpty, reason: 'no declarations were found');
        final word = RegExp(r'\b(' + symbols.join('|') + r')\b');
        // A one-word name (`Task`) is also an English word, so inside a fence
        // - a sample bug report, a string literal - it is prose. Only
        // compound names count there.
        final compound = RegExp(
          r'\b(' +
              symbols
                  .where((s) => !RegExp(r'^[A-Z][a-z]+$').hasMatch(s))
                  .join('|') +
              r')\b',
        );

        final hits = <String>[];
        for (final file in _markdown()) {
          final path = file.path.substring(root.length + 1);
          if (_isHistory(path) || sample.deletedDocs.contains(path)) continue;
          for (final (number, line, inFence) in _unmarkedLines(
            file.readAsStringSync(),
            sample.tag,
          )) {
            final text = inFence
                ? line
                : RegExp(
                    '`([^`]+)`',
                  ).allMatches(line).map((m) => m.group(1)!).join(' ');
            final named = [
              ...(inFence ? compound : word)
                  .allMatches(text)
                  .map((m) => m.group(1)!),
              ...sample.extraTokens.where(line.contains),
            ];
            if (named.isNotEmpty) hits.add('$path:$number: ${named.toSet()}');
          }
        }
        expect(hits, isEmpty, reason: hits.join('\n'));
      },
      skip: sources == null
          ? '${sample.tag} sources are in neither the working tree nor HEAD'
          : false,
    );
  }
}
