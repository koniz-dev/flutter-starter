import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';

import 'file:///Users/nguyenanhkiet/Playground/flutter-starter-1372/tool/doc_fences.dart';

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
  for (final rev in ['d2f223b6a25429a294ee4476ca0209691bda307a']) {
    final paths=(Process.runSync('git',['ls-tree','-r','--name-only',rev]).stdout as String).split('\n').where((p)=>p.endsWith('.md'));
    final errors=<String>[];
    for (final path in paths) {
      final contents=Process.runSync('git',['show','$rev:$path']).stdout as String;
      for(final p in _problems(contents)) {errors.add('$path: $p');}
    }
    print('$rev: ${errors.length} findings');
    for(final error in errors) {print(error);}
  }
  const bad='final useCase=LoginUseCase(repository); await useCase(email,password); Navigator.push(context,route);';
  for(final doc in ['```dart\n$bad\n```','> ```dart\n> $bad\n> ```','~~~~dart\n$bad\n~~~~','````dart\n/// ```dart\n/// $bad\n/// ```\n````']) {
    if(_problems(doc).isEmpty) {throw StateError('Failed bad fence: $doc');}
  }
  const good="final result=await loginUseCase(email,password); print('Navigator.push(context,route)'); // navigateToHome()";
  if(_problems('```dart\n$good\n```').isNotEmpty) {throw StateError('Failed lexical control');}
  print('Independent fence and lexical controls passed');
}
