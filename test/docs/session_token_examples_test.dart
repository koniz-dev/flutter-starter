import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/token.dart';
// Scan partial examples using the same lexer as the Dart analyzer.
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_fences.dart';

// This guard recognizes the storage and logging idioms used by the examples;
// it does not execute documentation or attempt whole-program type inference.
final _tokenName = RegExp(r'\b\w*token\w*\b', caseSensitive: false);
typedef _Lexeme = ({String text, int offset, bool literal, bool identifier});

List<_Lexeme> _lex(String source) {
  final features = FeatureSet.latestLanguageVersion();
  final scanner = Scanner(inputText: source, reportError: (_) {})
    ..configureFeatures(featureSetForOverriding: features, featureSet: features)
    ..preserveComments = false;
  return [
    for (var t = scanner.tokenize(); t.type != TokenType.EOF; t = t.next!)
      if (t.type != TokenType.BAD_INPUT && !t.isSynthetic)
        (
          text: t.lexeme,
          offset: t.offset,
          literal: t.type == TokenType.STRING,
          identifier: t.type == TokenType.IDENTIFIER,
        ),
  ];
}

bool _dartFence(String line) {
  final opening = fenceLike.firstMatch(line)!;
  final language = line
      .substring(opening.end)
      .trim()
      .split(RegExp(r'\s+'))
      .first;
  return language.isEmpty || language == 'dart';
}

String _dartExamples(String markdown) {
  final outer = FenceTracker();
  var nested = FenceTracker();
  var dart = false;
  var nestedDart = false;
  final lines = <String>[];
  for (final original in markdown.split('\n')) {
    final line = original.replaceFirst(RegExp(r'^(?:[ \t]*>[ \t]?)+'), '');
    final wasOpen = outer.inFence;
    if (outer.isFence(line)) {
      dart = !wasOpen && outer.inFence && _dartFence(line);
      nested = FenceTracker();
      nestedDart = false;
      lines.add('');
    } else if (!outer.inFence) {
      lines.add(
        RegExp(r'`([^`\n]+)`')
            .allMatches(line)
            .map((match) => match.group(1)!)
            .join('; '),
      );
    } else if (!dart) {
      lines.add('');
    } else if (line.trimLeft().startsWith('///')) {
      final comment = line.replaceFirst(RegExp(r'^[ \t]*/// ?'), '');
      final wasNested = nested.inFence;
      if (nested.isFence(comment)) {
        nestedDart = !wasNested && nested.inFence && _dartFence(comment);
        lines.add('');
      } else {
        lines.add(
          nested.inFence && nestedDart
              ? comment
              : RegExp(r'`([^`\n]+)`')
                    .allMatches(comment)
                    .map((match) => match.group(1)!)
                    .join('; '),
        );
      }
    } else {
      lines.add(line);
    }
  }
  return lines.join('\n');
}

int _close(List<_Lexeme> tokens, int open) {
  var depth = 0;
  for (var i = open; i < tokens.length; i++) {
    if (tokens[i].text == '(') depth++;
    if (tokens[i].text == ')' && --depth == 0) return i;
  }
  return -1;
}

int _open(List<_Lexeme> tokens, int close) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    if (tokens[i].text == ')') depth++;
    if (tokens[i].text == '(' && --depth == 0) return i;
  }
  return -1;
}

const _selectors = {'.', '?.', '..', '?..'};

bool _rawReceiver(List<_Lexeme> tokens, int member, Set<String> stores) {
  if (member < 2 || !_selectors.contains(tokens[member - 1].text)) return false;
  return _rawValue(tokens, member - 2, stores);
}

bool _rawValue(List<_Lexeme> tokens, int end, Set<String> stores) {
  if (end < 0) return false;
  if (tokens[end].text == '!') return _rawValue(tokens, end - 1, stores);
  if (tokens[end].text == ')') {
    final start = _open(tokens, end);
    if (start < 0) return false;
    if (start == 0 ||
        (!tokens[start - 1].identifier && tokens[start - 1].text != '>')) {
      return _rawValue(tokens, end - 1, stores);
    }
    var function = start - 1;
    if (tokens[function].text == '>') {
      var depth = 1;
      while (--function >= 0) {
        if (tokens[function].text == '>') depth++;
        if (tokens[function].text == '<' && --depth == 0) break;
      }
      function--;
    }
    if (function < 0) return false;
    if (stores.contains(tokens[function].text)) return true;
    if (tokens[function].text == 'read' &&
        tokens
            .sublist(function + 1, end)
            .any((t) => !t.literal && stores.contains(t.text))) {
      return true;
    }
    return _rawReceiver(tokens, function, stores);
  }
  return !tokens[end].literal &&
      (stores.contains(tokens[end].text) || _rawReceiver(tokens, end, stores));
}

bool _sessionKey(String argument) {
  const names = {
    'token',
    'authtoken',
    'accesstoken',
    'refreshtoken',
    'sessiontoken',
    'tokenkey',
    'refreshtokenkey',
  };
  final key = argument.split(',').first.trim();
  final literal = RegExp(r'''^[rR]?['"]([^'"]+)['"]$''').firstMatch(key);
  final name = literal?.group(1) ?? key.split('.').last;
  return names.contains(
    name.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase(),
  );
}

Set<String> _aliases(
  List<_Lexeme> tokens,
  Set<String> types,
  Set<String> initial,
) {
  final names = {...initial, ...types};
  for (var i = 0; i < tokens.length - 1; i++) {
    if (!types.contains(tokens[i].text)) continue;
    final next = i + (tokens[i + 1].text == '?' ? 2 : 1);
    if (next < tokens.length && tokens[next].identifier) {
      names.add(tokens[next].text);
    }
  }
  for (var i = 1; i < tokens.length; i++) {
    if (tokens[i].text != '=' || !tokens[i - 1].identifier) continue;
    final end = tokens.indexWhere((t) => t.text == ';', i + 1);
    if (end >= 0 &&
        tokens
            .sublist(i + 1, end)
            .any((t) => !t.literal && names.contains(t.text))) {
      names.add(tokens[i - 1].text);
    }
  }
  return names;
}

List<String> _violations(String code) {
  final source = code.replaceAll(RegExp(r'^[ \t]*/// ?', multiLine: true), '');
  final tokens = _lex(source);
  final stores = _aliases(
    tokens,
    {
      'SecureStorageService',
      'IStorageService',
      'IKeyValueStore',
    },
    {'secureStorage', 'secureStorageService', 'secureStorageServiceProvider'},
  );
  final loggers = _aliases(
    tokens,
    {'Logger', 'LoggingService'},
    {
      'logger',
      'loggingService',
      for (final t in tokens)
        if (t.identifier &&
            RegExp(r'\w*logger$', caseSensitive: false).hasMatch(t.text))
          t.text,
    },
  );
  const methods = {
    'print',
    'debugPrint',
    'log',
    'd',
    'i',
    'w',
    'e',
    'info',
    'debug',
    'warning',
    'error',
    'getString',
    'setString',
    'getInt',
    'setInt',
    'getBool',
    'setBool',
    'getDouble',
    'setDouble',
    'getStringList',
    'setStringList',
    'remove',
    'clear',
    'containsKey',
  };
  final problems = <String>[];
  for (var i = 0; i < tokens.length - 1; i++) {
    final method = tokens[i].text;
    if (tokens[i].literal ||
        !methods.contains(method) ||
        tokens[i + 1].text != '(') {
      continue;
    }
    final end = _close(tokens, i + 1);
    if (end < 0) continue;
    final arguments = tokens.sublist(i + 2, end);
    final argument = arguments.map((t) => t.text).join(' ');
    final line =
        '\n'.allMatches(source.substring(0, tokens[i].offset)).length + 1;
    final logs =
        {'print', 'debugPrint', 'log'}.contains(method) ||
        _rawReceiver(tokens, i, loggers);
    final tokenValue = arguments.any(
      (t) => !t.literal && _tokenName.hasMatch(t.text),
    );
    if (logs && tokenValue) {
      problems.add('$line: token value passed to $method');
    } else if (_rawReceiver(tokens, i, stores) &&
        (method == 'clear' || _sessionKey(argument))) {
      problems.add('$line: session token operation bypasses ITokenStore');
    }
  }
  return problems;
}

void main() {
  for (final bad in [
    "await secureStorage.setString('token', value);",
    "await secureStorage.getString('refresh_token');",
    'await secureStorage.remove(StorageKeys.token);',
    'await secureStorage.getString(AppConstants.tokenKey);',
    "await secureStorage.setString('accessToken', value);",
    'await secureStorage.setBool(AppConstants.tokenKey, value: true);',
    '''
await ref.read(secureStorageServiceProvider)
  .getString(StorageKeys.token);
''',
    'await secureStorage.clear();',
    "secureStorage.remove(/* session key */ 'token');",
    "(secureStorage).remove('token');",
    "(secureStorage!).remove('token');",
    'logger!.info(accessToken);',
    'LoggingService audit; audit.info(accessToken);',
    "IKeyValueStore prefs; prefs.setString('token', token);",
    "await secureStorage?.getString('token');",
    "await secureStorage!.remove('token');",
    "secureStorage..remove('token');",
    "secureStorage?..remove('refresh_token');",
    '''
final IKeyValueStore secrets = ref.read(secureStorageServiceProvider);
secrets.remove('token');
''',
    "secureStorage..getString('api_key')..remove('token');",
    "secureStorage..getString('token')..remove('api_key');",
    "final secret = SecureStorageService(); secret.remove('auth_token');",
    '''
final secret = ref.read(secureStorageServiceProvider);
secret.getString('token');
''',
    'SecureStorageService secret; secret.remove(StorageKeys.refreshToken);',
    r"print('New token: $token');",
    'print(newToken);',
    r"logger.d('Token: $accessToken');",
    r"print('); Token: $token');",
    r"debugPrint('Token: ${response.accessToken}');",
    "print('result: ' + refreshToken);",
    r"/// success: (token) => print('New token: $token'),",
  ]) {
    final label = bad.trim().replaceAll(RegExp(r'\s+'), ' ');
    test('rejects unsafe example: $label', () {
      expect(_violations(bad), isNotEmpty);
    });
  }
  for (final safe in [
    'await tokenStore.setAccessToken(accessToken);',
    'await tokenStore.getRefreshToken();',
    'await authRepository.logout();',
    "IKeyValueStore prefs; prefs.setString('theme_mode', 'dark');",
    "await secureStorage.getString('api_key');",
    "await secureStorage.setString('api_key', apiKey);",
    "print('Token refreshed successfully');",
    "print('Use print(token) to inspect it');",
    "print('Done' /* token */);",
    "/* /* nested */ secureStorage.remove('token'); */",
    r"print('${'Token refreshed'}');",
    r"print(r'Token example: $token');",
    r"print('Token example: \$token');",
  ]) {
    test('allows safe example: $safe', () {
      expect(_violations(safe), isEmpty);
    });
  }
  test('prose and non-Dart fences do not become executable calls', () {
    const markdown = '''
A user's guide describes print(token) in prose.
```text
print(token)
```
```dart
// A user's comment must not start a string.
print('Token refreshed successfully');
```
''';
    expect(_violations(_dartExamples(markdown)), isEmpty);
  });

  test('Dart doc-comment examples are checked without parsing their prose', () {
    const markdown = '''
```dart
/// The user's session.
class Example {
  /// ```dart
  /// print(token);
  /// ```
}
```
''';
    expect(_violations(_dartExamples(markdown)), hasLength(1));
  });

  test('blockquote and inline Dart-doc examples are checked', () {
    const markdown = '''
> ```dart
> print(token);
> ```
```dart
/// Example: `print(accessToken)`
void example() {}
```
''';
    expect(_violations(_dartExamples(markdown)), hasLength(2));
  });

  test('inline storage examples are checked', () {
    const markdown = "Inline `secureStorage.remove('token')` example.";
    expect(_violations(_dartExamples(markdown)), hasLength(1));
  });

  test(
    'documentation uses token lifecycle contracts and never prints tokens',
    () {
      final problems = <String>[
        for (final file in Directory('docs').listSync(recursive: true))
          if (file is File && file.path.endsWith('.md'))
            for (final problem in _violations(
              _dartExamples(file.readAsStringSync()),
            ))
              '${file.path}:$problem',
      ];
      expect(problems, isEmpty);
    },
  );
}
