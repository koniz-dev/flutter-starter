import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
void main() {
 const r='***REDACTED***';
 const cases={
  '/cb?ticket=Q#access_token=F': '/cb?ticket=$r#access_token=$r',
  '/cb#access_token=F?code=stillF&state=ok': '/cb#access_token=$r&state=ok',
  '/cb#access_token=F#code=stillF&state=ok': '/cb#access_token=$r&state=ok',
  '/cb#/route?state=ok&ticket=F': '/cb#/route?state=ok&ticket=$r',
  '/cb#!/route?state=ok&tic%6bet=F': '/cb#!/route?state=ok&tic%6bet=$r',
  '/cb?view=public#guide?view=compact': '/cb?view=public#guide?view=compact',
  '/cb#code=F&code=G&ticket=H': '/cb#code=$r&code=$r&ticket=$r',
  '//user:pw@host/cb?ticket=Q#id_token=F': '//$r@host/cb?ticket=$r#id_token=$r',
 };
 for(final e in cases.entries) {
  test('boundary ${e.key}', () {expect(ApiLoggingInterceptor.redactUrl(e.key), e.value); expect(ApiLoggingInterceptor.redactUrl(e.value), e.value);});
 }
}
