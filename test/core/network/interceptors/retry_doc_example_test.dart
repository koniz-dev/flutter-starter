// The ApiClient example in RetryInterceptor's class doc must use parameters
// ApiClient.post really has.
//
// It passed `options: Options(headers: ...)`, and ApiClient.post has no
// `options` parameter, so an adopter copying the documented way to opt a POST
// into replay got an analyzer error. This reads the example out of the doc
// comment and checks its call shape against the real signature, so the two
// cannot drift apart again.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _retryInterceptor =
    'lib/core/network/interceptors/retry_interceptor.dart';
const _apiClient = 'lib/core/network/api_client.dart';

/// The `apiClient.post(...)` call in [source]'s doc comments, with the `///`
/// prefixes removed.
String? _documentedPostCall(String source) {
  final doc = source
      .split('\n')
      .where((l) => l.trimLeft().startsWith('///'))
      .map((l) => l.trimLeft().substring(3))
      .join('\n');
  return RegExp(
    r'apiClient\.post\((.*?)\n\s*\);',
    dotAll: true,
  ).firstMatch(doc)?.group(1);
}

/// The named parameters of `ApiClient.post`, read from its declaration.
Set<String> _postParameters(String source) {
  final signature = RegExp(
    r'Future<NetworkResponse<dynamic>> post\(\s*String path, \{(.*?)\}\)',
    dotAll: true,
  ).firstMatch(source)!.group(1)!;
  return {
    for (final m in RegExp(r'(\w+),?\s*$', multiLine: true).allMatches(
      signature,
    ))
      m.group(1)!,
  };
}

/// The named arguments a call body passes, at its top level.
Set<String> _namedArguments(String call) => {
  for (final m in RegExp(
    r'^\s*(\w+):',
    multiLine: true,
  ).allMatches(call))
    m.group(1)!,
};

void main() {
  final retrySource = File(_retryInterceptor).readAsStringSync();
  final parameters = _postParameters(File(_apiClient).readAsStringSync());

  test('the signature parse sees ApiClient.post', () {
    expect(parameters, {'data', 'queryParameters', 'headers', 'cancellation'});
  });

  test('criterion 2: the documented apiClient.post call uses only real '
      'parameters', () {
    final call = _documentedPostCall(retrySource);
    expect(call, isNotNull, reason: 'no apiClient.post example in the doc');

    final passed = _namedArguments(call!);
    expect(passed, isNotEmpty);
    expect(
      passed.difference(parameters),
      isEmpty,
      reason: 'the example passes parameters ApiClient.post does not have',
    );
  });

  test('criterion 1: the example sends the key through headers:', () {
    final call = _documentedPostCall(retrySource)!;
    expect(call, contains('headers: {RetryInterceptor.idempotencyKeyHeader'));
  });

  test('the check rejects the pre-#296 example', () {
    const before = '''
/// apiClient.post(
///   '/orders',
///   data: body,
///   options: Options(headers: {'Idempotency-Key': key}),
/// );
''';
    final passed = _namedArguments(_documentedPostCall(before)!);
    expect(passed.difference(parameters), {'options'});
  });
}
