import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_fences.dart';

// A vocabulary guard for the documented login/navigation idioms, not a
// whole-program call graph. Lexing avoids treating comments/strings as calls.
List<String> _tokens(String source) {
  final features = FeatureSet.latestLanguageVersion();
  final scanner = Scanner(inputText: source, reportError: (_) {})
    ..configureFeatures(featureSetForOverriding: features, featureSet: features)
    ..preserveComments = false;
  return [
    for (var t = scanner.tokenize(); t.type != TokenType.EOF; t = t.next!)
      if (t.type != TokenType.STRING &&
          t.type != TokenType.BAD_INPUT &&
          !t.isSynthetic)
        t.lexeme,
  ];
}

List<String> _dartBlocks(String markdown) {
  final tracker = FenceTracker();
  final blocks = <String>[];
  var body = <String>[];
  var dart = false;
  for (final original in markdown.split('\n')) {
    final line = original.replaceFirst(RegExp(r'^(?:[ \t]*>[ \t]?)+'), '');
    final wasOpen = tracker.inFence;
    if (tracker.isFence(line)) {
      if (!wasOpen) {
        final match = fenceLike.firstMatch(line)!;
        final language = line
            .substring(match.end)
            .trim()
            .split(RegExp(r'\s+'))
            .first;
        dart = language.isEmpty || language == 'dart';
        body = [];
      } else if (dart) {
        blocks.add(body.join('\n'));
      }
    } else if (tracker.inFence && dart) {
      body.add(line);
    }
  }
  return [
    for (final block in blocks) ...[
      block,
      // Dartdoc examples are executable guidance inside an outer Dart fence.
      ..._dartBlocks(
        block
            .split('\n')
            .where((line) => line.trimLeft().startsWith('///'))
            .map((line) => line.replaceFirst(RegExp(r'^[ \t]*/// ?'), ''))
            .join('\n'),
      ),
    ],
  ];
}

List<String> _problems(String markdown) {
  final problems = <String>[];
  for (final block in _dartBlocks(markdown)) {
    final tokens = _tokens(block);
    if (!tokens.any(
      const {
        'loginUseCase',
        'LoginUseCase',
        'loginUseCaseProvider',
      }.contains,
    )) {
      continue;
    }
    final navigation =
        tokens.any((t) => t.startsWith('navigateTo') || t == 'Navigator') ||
        RegExp(r'\b(?:context|router)\s*\.\s*(?:go|push|replace)\w*\s*\(')
            .hasMatch(tokens.join(' '));
    final widget =
        tokens.contains('WidgetRef') ||
        tokens.contains('ConsumerStatefulWidget') ||
        tokens.contains('ConsumerState') ||
        tokens.contains('ConsumerWidget');
    if (navigation || widget) {
      problems.add('A UI/navigation example bypasses AuthNotifier.login');
    }
  }
  return problems;
}

void main() {
  test(
    'all documented UI login flows publish the session through AuthNotifier',
    () {
      final paths =
          (Process.runSync('git', ['ls-files', '*.md']).stdout as String).split(
            '\n',
          );
      final problems = <String>[];
      for (final path in paths.where((p) => p.isNotEmpty)) {
        final file = File(path);
        if (file.existsSync()) {
          problems.addAll(
            _problems(file.readAsStringSync()).map((p) => '$path: $p'),
          );
        }
      }
      expect(problems, isEmpty);
    },
  );

  test('guard rejects direct, aliased and Dartdoc use-case navigation', () {
    for (final code in [
      '''
class Login extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.read(loginUseCaseProvider);
    return button(() => call(email, password));
  }
}
''',
      'final result = await loginUseCase(email, password); navigateToHome();',
      '''
final call = ref.read(loginUseCaseProvider);
await call(email, password);
router.go('/home');
''',
      '''
final call = LoginUseCase(repository);
await call(email, password);
context.goToHome();
''',
    ]) {
      expect(_problems('```dart\n$code\n```'), isNotEmpty);
      final dartdoc = code.split('\n').map((line) => '/// $line').join('\n');
      expect(
        _problems('```dart\n/// ```dart\n$dartdoc\n/// ```\n```'),
        isNotEmpty,
      );
      expect(_problems('~~~~dart\n$code\n~~~~'), isNotEmpty);
    }
  });

  test('guard accepts session-owner UI, domain-only results and text', () {
    for (final code in [
      '''
await ref.read(authNotifierProvider.notifier).login(email, password);
router.go('/home');
''',
      'final result = await loginUseCase(email, password); handleUser(result);',
      '''
final result = await loginUseCase(email, password);
print('navigateToHome()'); // Navigator.push()
''',
    ]) {
      expect(_problems('```dart\n$code\n```'), isEmpty);
    }
  });
}
