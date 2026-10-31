// Pins every redaction rule in ApiLoggingInterceptor, one realistic key per
// rule.
//
// The existing tests exercised a handful of keys, so removing `secret` - or any
// of a dozen other entries in `_sensitiveKeyFragments` / `_sensitiveKeysExact`
// - left the suite green, and so did logging `response.data` unsanitized,
// which is the class of leak this guards. Each key below is chosen so that
// only its own rule matches it: drop that one entry and exactly that case
// fails.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoggingService extends Mock implements LoggingService {}

class _RequestHandler extends RequestInterceptorHandler {}

class _ResponseHandler extends ResponseInterceptorHandler {}

const _redacted = '***REDACTED***';

/// Rule -> a body key that only that rule matches.
const _fragmentKeys = <String, String>{
  'password': 'user_password',
  'passwd': 'db_passwd',
  'passphrase': 'wallet_passphrase',
  'token': 'refresh_token',
  'secret': 'client_secret',
  'apikey': 'apiKey',
  'credential': 'credentials',
  'authorization': 'authorization',
  'privatekey': 'private_key',
  'creditcard': 'credit_card',
  'cardnumber': 'card_number',
  'signature': 'signature',
  'pincode': 'pin_code',
  'otpcode': 'otp_code',
  'jwt': 'jwt',
  'accesskey': 'access_key',
  'appkey': 'app_key',
  'clientkey': 'client_key',
  'hmac': 'x-hmac-sha256',
  'subscriptionkey': 'Ocp-Apim-Subscription-Key',
  'functionskey': 'x-functions-key',
  'sessionkey': 'session_key',
  'authkey': 'auth_key',
  'masterkey': 'master_key',
  'licensekey': 'license_key',
};

const _exactKeys = <String, String>{
  'pin': 'pin',
  'otp': 'otp',
  'cvv': 'cvv',
  'cvc': 'cvc',
  'session': 'session',
  'sessionid': 'sessionId',
  'bearer': 'bearer',
  'sign': 'sign',
  'key': 'key',
  'access': 'access',
  'refresh': 'refresh',
};

void main() {
  late _MockLoggingService logging;
  late ApiLoggingInterceptor interceptor;

  setUp(() {
    logging = _MockLoggingService();
    interceptor = ApiLoggingInterceptor(loggingService: logging);
  });

  Map<String, dynamic> loggedRequestQuery(Map<String, dynamic> query) {
    Map<String, dynamic>? context;
    when(
      () => logging.debug(any(), context: any(named: 'context')),
    ).thenAnswer((invocation) {
      context = invocation.namedArguments[#context] as Map<String, dynamic>?;
    });
    interceptor.onRequest(
      RequestOptions(path: '/api/x', queryParameters: query),
      _RequestHandler(),
    );
    return context!['queryParameters'] as Map<String, dynamic>;
  }

  Map<String, dynamic> loggedRequestBody(Map<String, dynamic> body) {
    Map<String, dynamic>? context;
    when(
      () => logging.debug(any(), context: any(named: 'context')),
    ).thenAnswer((invocation) {
      context = invocation.namedArguments[#context] as Map<String, dynamic>?;
    });
    interceptor.onRequest(
      RequestOptions(path: '/api/x', method: 'POST', data: body),
      _RequestHandler(),
    );
    return context!['body'] as Map<String, dynamic>;
  }

  group('criterion 1: every key rule redacts its realistic key', () {
    for (final MapEntry(key: rule, value: key) in {
      ..._fragmentKeys,
      ..._exactKeys,
    }.entries) {
      test('$rule -> "$key"', () {
        final body = loggedRequestBody({key: 'S3CRET', 'note': 'kept'});

        expect(body[key], _redacted, reason: 'rule "$rule" must redact $key');
        // The rule is not a blanket: an innocent field survives.
        expect(body['note'], 'kept');
      });
    }

    test('near misses of the short names stay readable', () {
      for (final key in [
        'monkey',
        'keyword',
        'signal',
        'signup',
        'code',
        'error_code',
        'bearing',
        'accessLevel',
        'refreshInterval',
        'lastRefresh',
        'access_level',
      ]) {
        expect(
          ApiLoggingInterceptor.isSensitiveKey(key),
          isFalse,
          reason: key,
        );
      }
    });

    test('the table covers both rule sets with no duplicates', () {
      // 25 fragment rules + 11 exact rules (plus sig and auth, pinned in the
      // path redaction tests), as declared in
      // api_logging_interceptor.dart; growing either set without a row here
      // leaves the new rule unpinned.
      expect(_fragmentKeys, hasLength(25));
      expect(_exactKeys, hasLength(11));
      expect(
        {..._fragmentKeys.values, ..._exactKeys.values},
        hasLength(_fragmentKeys.length + _exactKeys.length),
      );
    });
  });

  test('criterion 2: onResponse never logs an access_token value', () {
    Map<String, dynamic>? context;
    when(
      () => logging.info(any(), context: any(named: 'context')),
    ).thenAnswer((invocation) {
      context = invocation.namedArguments[#context] as Map<String, dynamic>?;
    });

    interceptor.onResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/auth/login', method: 'POST'),
        statusCode: 200,
        data: {'access_token': 'T0KEN-VALUE', 'user': 'u'},
      ),
      _ResponseHandler(),
    );

    expect(context, isNotNull);
    expect(context.toString(), isNot(contains('T0KEN-VALUE')));
    expect((context!['body'] as Map)['access_token'], _redacted);
  });

  test('a SimpleJWT login response logs neither token', () {
    Map<String, dynamic>? context;
    when(
      () => logging.info(any(), context: any(named: 'context')),
    ).thenAnswer((invocation) {
      context = invocation.namedArguments[#context] as Map<String, dynamic>?;
    });
    when(
      () => logging.debug(any(), context: any(named: 'context')),
    ).thenAnswer((invocation) {
      context ??= invocation.namedArguments[#context] as Map<String, dynamic>?;
    });
    final options = RequestOptions(path: '/api/token/', method: 'POST');
    interceptor.onResponse(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'access': 'ACCESS-JWT',
          'refresh': 'REFRESH-JWT',
          'accessLevel': 1,
        },
      ),
      _ResponseHandler(),
    );

    final logged = '$context';
    expect(logged, isNot(contains('ACCESS-JWT')));
    expect(logged, isNot(contains('REFRESH-JWT')));
    expect(logged, contains('accessLevel: 1'));
  });

  group('code is a secret in a query string only', () {
    test('a query code is redacted in the path and the query parameters', () {
      expect(ApiLoggingInterceptor.isSensitiveQueryKey('code'), isTrue);
      final path = ApiLoggingInterceptor.redactPath(
        '/api/HttpTrigger?code=FUNCTION-KEY&name=x',
      );
      expect(path, isNot(contains('FUNCTION-KEY')));
      expect(path, contains('name=x'));

      final body = loggedRequestQuery({'code': 'OAUTH-CODE', 'state': 's'});
      expect(body['code'], _redacted);
      expect(body['state'], 's');
    });

    test('a body field code stays readable', () {
      expect(ApiLoggingInterceptor.isSensitiveKey('code'), isFalse);
      final body = loggedRequestBody({'code': 404, 'message': 'missing'});
      expect(body['code'], 404);
    });
  });
}
