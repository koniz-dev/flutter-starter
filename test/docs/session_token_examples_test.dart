import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_fences.dart';

// This guard recognizes the storage and logging idioms used by the examples;
// it does not execute documentation or attempt whole-program type inference.
final _literal = RegExp(
  r'''[rR]?(?:'{3}[\s\S]*?'{3}|"{3}[\s\S]*?"{3}|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''',
);
final _tokenName = RegExp(r'\b\w*token\w*\b', caseSensitive: false);
typedef _Lexeme = ({String text, int offset, bool literal});

List<_Lexeme> _lex(String source) {
  final pattern = RegExp(
    r'//[^\n]*|/\*[\s\S]*?\*/|'
    '${_literal.pattern}'
    r'|[A-Za-z_$][\w$]*|\?\.\.|\?\.|\.\.|\S',
  );
  return [
    for (final match in pattern.allMatches(source))
      if (!match.group(0)!.startsWith('//') &&
          !match.group(0)!.startsWith('/*'))
        (
          text: match.group(0)!,
          offset: match.start,
          literal:
              _literal.matchAsPrefix(source, match.start)?.end == match.end,
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
  for (final line in markdown.split('\n')) {
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
        lines.add(nested.inFence && nestedDart ? comment : '');
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
    if (start < 1) return false;
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

bool _printsToken(String body) {
  for (final literal in _literal.allMatches(body)) {
    final text = literal.group(0)!;
    if (text.startsWith('r') || text.startsWith('R')) continue;
    for (final expression in RegExp(
      r'\$(\w+)|\$\{([^}]*)\}',
    ).allMatches(text)) {
      var escapes = 0;
      for (var i = expression.start - 1; i >= 0 && text[i] == r'\'; i--) {
        escapes++;
      }
      if (escapes.isOdd) continue;
      if (_tokenName.hasMatch(expression.group(1) ?? expression.group(2)!)) {
        return true;
      }
    }
  }
  return _tokenName.hasMatch(body.replaceAll(_literal, ' '));
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

List<String> _violations(String code) {
  final source = code.replaceAll(RegExp(r'^[ \t]*/// ?', multiLine: true), '');
  final tokens = _lex(source);
  final stores = <String>{
    'secureStorage',
    'secureStorageService',
    'SecureStorageService',
    'secureStorageServiceProvider',
  };
  const rawTypes = {
    'SecureStorageService',
    'IStorageService',
    'IKeyValueStore',
  };
  for (var i = 0; i < tokens.length - 1; i++) {
    if (!rawTypes.contains(tokens[i].text)) continue;
    final next = i + (tokens[i + 1].text == '?' ? 2 : 1);
    if (next < tokens.length &&
        RegExp(r'^[A-Za-z_$][\w$]*$').hasMatch(tokens[next].text) &&
        !{'implements', 'extends', 'with'}.contains(tokens[next].text)) {
      stores.add(tokens[next].text);
    }
  }
  for (var i = 1; i < tokens.length; i++) {
    if (tokens[i].text != '=') continue;
    final end = tokens.indexWhere((t) => t.text == ';', i + 1);
    if (end < 0) continue;
    if (tokens
        .sublist(i + 1, end)
        .any((t) => !t.literal && stores.contains(t.text))) {
      stores.add(tokens[i - 1].text);
    }
  }
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
    final argument = source.substring(
      tokens[i + 1].offset + 1,
      tokens[end].offset,
    );
    final line =
        '\n'.allMatches(source.substring(0, tokens[i].offset)).length + 1;
    final receiver = i >= 2 ? tokens[i - 2].text : '';
    final logs =
        {'print', 'debugPrint', 'log'}.contains(method) ||
        RegExp(
          r'\b(?:\w*logger|loggingService)\b',
          caseSensitive: false,
        ).hasMatch(receiver);
    if (logs && _printsToken(argument)) {
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
