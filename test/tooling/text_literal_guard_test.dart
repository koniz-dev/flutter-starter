// No hard-coded words in a `Text(` under presentation code.
//
// English kept reaching shipped screens as `Text('...')` literals and
// nothing failed when it did. This scans
// `lib/features/**/presentation` and `lib/shared/widgets` for a string
// literal passed straight to `Text(`, single-line or multi-line.
//
// What counts: a literal with a letter in it once its `$name` / `${...}`
// interpolations are removed. `'$label: '` - an already-localized label plus
// punctuation - holds no word to translate, so it passes; `'Retry'` and
// `'Hello $name'` fail.
//
// The one exception is an allow-list comment on the line of the `Text(` or
// the line above it, with a reason:
//
//     // l10n-literal-ok: brand name, never translated
//     Text('Flutter Starter'),

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _roots = ['lib/features', 'lib/shared/widgets'];
const _allowMarker = 'l10n-literal-ok:';

final RegExp _textCall = RegExp(
  r'''\bText\s*\(\s*(?:const\s+)?r?(['"])((?:\\.|(?!\1).)*)\1''',
  dotAll: true,
);
final RegExp _interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*');
final RegExp _letter = RegExp(r'\p{L}', unicode: true);

/// Whether [path] is presentation code this guard covers.
bool _inScope(String path) {
  final p = path.replaceAll(r'\', '/');
  if (!p.endsWith('.dart') ||
      p.endsWith('.g.dart') ||
      p.endsWith('.freezed.dart')) {
    return false;
  }
  return p.startsWith('lib/shared/widgets/') ||
      (p.startsWith('lib/features/') && p.contains('/presentation/'));
}

/// `path:line: snippet` for each unallowed literal passed to `Text(` in
/// [source].
List<String> _literals(String path, String source) {
  final lines = source.split('\n');
  final problems = <String>[];
  for (final match in _textCall.allMatches(source)) {
    final body = match.group(2)!;
    if (!_letter.hasMatch(body.replaceAll(_interpolation, ''))) continue;
    final line = '\n'.allMatches(source.substring(0, match.start)).length;
    final here = lines[line];
    final above = line > 0 ? lines[line - 1] : '';
    if (here.contains(_allowMarker) || above.contains(_allowMarker)) continue;
    problems.add('$path:${line + 1}: Text(${match.group(1)}$body…');
  }
  return problems;
}

void main() {
  test('criterion 1: no string literal is passed to Text( in presentation '
      'code', () {
    final files = [
      for (final root in _roots)
        if (Directory(root).existsSync())
          ...Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => _inScope(f.path)),
    ];
    expect(files, isNotEmpty, reason: 'the scan must see some files');

    final problems = [
      for (final f in files) ..._literals(f.path, f.readAsStringSync()),
    ];
    expect(
      problems,
      isEmpty,
      reason:
          'Use AppLocalizations instead, or allow-list the line with '
          '"// $_allowMarker <reason>":\n${problems.join('\n')}',
    );
  });

  group('criterion 2: the scan itself', () {
    List<String> scan(String source) =>
        _literals('lib/features/x/presentation/x.dart', source);

    test('catches a planted single-line literal', () {
      expect(scan("child: Text('Retry'),"), hasLength(1));
      expect(scan('child: const Text("Retry"),'), hasLength(1));
    });

    test('catches a planted multi-line literal, naming its line', () {
      final problems = scan('''
Column(
  children: [
    Text(
      'Add screens under lib/features/.',
      style: style,
    ),
  ],
)''');
      expect(problems, hasLength(1));
      expect(
        problems.single,
        startsWith('lib/features/x/presentation/x.dart:3:'),
      );
    });

    test('catches words around an interpolation', () {
      expect(scan(r"Text('Hello $name')"), hasLength(1));
      expect(scan(r"Text('${count} items')"), hasLength(1));
    });

    test(
      'passes a localized call and punctuation around a localized label',
      () {
        expect(scan('Text(l10n.retry)'), isEmpty);
        expect(scan('Text(failure.localizedMessage(l10n))'), isEmpty);
        expect(scan(r"Text('$label: ')"), isEmpty);
        expect(scan(r"Text('${l10n.count}: ${value}')"), isEmpty);
      },
    );

    test('honours the allow-list comment on the line or the line above', () {
      expect(
        scan("// $_allowMarker brand name\nText('Flutter Starter')"),
        isEmpty,
      );
      expect(
        scan("Text('Flutter Starter'), // $_allowMarker brand name"),
        isEmpty,
      );
    });

    test('scopes to presentation code and shared widgets', () {
      expect(
        _inScope('lib/features/tasks/presentation/screens/a.dart'),
        isTrue,
      );
      expect(_inScope('lib/shared/widgets/language_switcher.dart'), isTrue);
      expect(_inScope('lib/features/tasks/data/models/a.dart'), isFalse);
      expect(_inScope('lib/features/tasks/presentation/a.g.dart'), isFalse);
    });
  });
}
