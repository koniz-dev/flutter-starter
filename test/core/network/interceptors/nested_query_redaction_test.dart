// redactPath read query parameters one level deep, so a credential inside a
// URL carried in a parameter value, or after a `;` separator, passed in clear
// to logs, performance traces and retry logs.

import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (url, expected) in [
    (
      'https://h/cb?redirect=https://x/?code=SECRET',
      'https://h/cb?redirect=https://x/?code=***REDACTED***',
    ),
    (
      'https://h/cb?next=/y?token=SECRET',
      'https://h/cb?next=/y?token=***REDACTED***',
    ),
    (
      'https://h/cb#/route?a=1;token=SECRET',
      'https://h/cb#/route?a=1;token=***REDACTED***',
    ),
    (
      'https://h/cb?redirect=https://x/?code=SECRET&page=2',
      'https://h/cb?redirect=https://x/?code=***REDACTED***&page=2',
    ),
  ]) {
    test('redacts the nested credential in $url', () {
      final redacted = ApiLoggingInterceptor.redactUrl(url);

      expect(redacted, expected);
      expect(redacted, isNot(contains('SECRET')));
    });
  }

  test('non-sensitive nested parameters are kept as they were', () {
    const url = 'https://h/cb?next=/y?page=2&q=a;b=c#/r?x=y';

    expect(ApiLoggingInterceptor.redactUrl(url), url);
  });
}
