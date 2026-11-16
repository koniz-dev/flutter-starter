import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('nested encoded malformed OAuth secrets and idempotence', () {
    for(final prefix in ['cb?', '/a=b?', '!/a=b?', 'cb?view=x?', '/a=b?view=x?']) {
      for(final key in ['code','ticket','%74oken','to%FFken','bad%','access_token','co?de','tok?en','prefix?co?de','prefix?%63o?de','prefix?tic%6Bet']) {
        for(final secret in ['SECRET','SECRET?tail','SECRET?code=OTHER']) {
          final input = 'https://USER:PASS@h/cb#$prefix$key=$secret&state=ok';
          final result = ApiLoggingInterceptor.redactUrl(input);
          expect(result, isNot(contains('SECRET')), reason: input);
          expect(result, isNot(contains('OTHER')), reason: input);
          expect(result, isNot(contains('USER:PASS')), reason: input);
          expect(ApiLoggingInterceptor.redactUrl(result), result, reason: input);
        }
      }
    }
  });
  test('exact suffix boundary and encoded question controls', () {
    for(final raw in ['prefix?co?dex','prefix%3Fcode','prefix?ticketCount','prefix?keyx']) {
      final path='/cb#/a=b?$raw=public';
      expect(ApiLoggingInterceptor.redactUrl(path),path);
    }
    for(final raw in ['prefix?bad%?public','prefix?co?de','prefix?tic%6Bet']) {
      final path='/cb#/a=b?$raw=SECRET?tail';
      expect(ApiLoggingInterceptor.redactUrl(path),isNot(contains('SECRET')));
    }
  });
}

