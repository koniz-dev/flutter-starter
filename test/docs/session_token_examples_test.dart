import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Scan examples, including code nested in Dart doc comments. These patterns
// guard the supported storage/logging idioms rather than evaluate Dart code.
final _literal = RegExp(
  r'''[rR]?(?:'{3}[\s\S]*?'{3}|"{3}[\s\S]*?"{3}|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''',
);
final _tokenName = RegExp(r'\b\w*token\w*\b', caseSensitive: false);
final _call = RegExp(
  r'\b(?:([\w]+(?:\s*\([^()]*\))?(?:\s*\.\s*\w+(?:\s*\([^()]*\))?)*)\s*\.\s*)?'
  r'(print|debugPrint|log|d|i|w|e|info|debug|warning|error|(?:get|set)(?:String|Int|Bool|Double|StringList)|remove|clear|containsKey)\s*\(',
);

String? _body(String source, int start) {
  var depth = 1;
  for (var i = start; i < source.length; i++) {
    final literal = _literal.matchAsPrefix(source, i);
    if (literal != null) {
      i = literal.end - 1;
      continue;
    }
    if (source[i] == '(') depth++;
    if (source[i] == ')' && --depth == 0) return source.substring(start, i);
  }
  return null;
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

List<String> _violations(String markdown) {
  final source = markdown.replaceAll(
    RegExp(r'^[ \t]*/// ?', multiLine: true),
    '',
  );
  final stores = <String>{
    'secureStorage',
    'secureStorageService',
    'SecureStorageService',
    'secureStorageServiceProvider',
  };
  for (final declaration in RegExp(
    r'\bSecureStorageService\s+(\w+)',
  ).allMatches(source)) {
    stores.add(declaration.group(1)!);
  }
  for (final declaration in RegExp(
    r'\b(?:final|var)\s+(?:SecureStorageService\s+)?(\w+)\s*=\s*([^;]+);',
  ).allMatches(source)) {
    final initializer = declaration.group(2)!;
    if (stores.any((name) => RegExp('\\b$name\\b').hasMatch(initializer))) {
      stores.add(declaration.group(1)!);
    }
  }
  final problems = <String>[];
  for (final call in _call.allMatches(source)) {
    final body = _body(source, call.end);
    if (body == null) continue;
    final receiver = call.group(1) ?? '';
    final method = call.group(2)!;
    final line = '\n'.allMatches(source.substring(0, call.start)).length + 1;
    final logs =
        method == 'print' ||
        method == 'debugPrint' ||
        method == 'log' ||
        RegExp(
          r'\b(?:\w*logger|loggingService)\b',
          caseSensitive: false,
        ).hasMatch(receiver);
    if (logs && _printsToken(body)) {
      problems.add('$line: token value passed to $method');
    } else if (stores.any((name) => RegExp('\\b$name\\b').hasMatch(receiver)) &&
        (method == 'clear' || _sessionKey(body))) {
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
    "await secureStorage.getString('api_key');",
    "await secureStorage.setString('api_key', apiKey);",
    "print('Token refreshed successfully');",
    r"print(r'Token example: $token');",
    r"print('Token example: \$token');",
  ]) {
    test('allows safe example: $safe', () {
      expect(_violations(safe), isEmpty);
    });
  }
  test(
    'documentation uses token lifecycle contracts and never prints tokens',
    () {
      final problems = <String>[
        for (final file in Directory('docs').listSync(recursive: true))
          if (file is File && file.path.endsWith('.md'))
            for (final problem in _violations(file.readAsStringSync()))
              '${file.path}:$problem',
      ];
      expect(problems, isEmpty);
    },
  );
}
