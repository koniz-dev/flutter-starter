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

  // Pre-merge review: the form Uri and dio actually produce is
  // percent-encoded, and the first version scanned to the end of the URL for
  // every sensitive key (quadratic on a long query).
  test('a percent-encoded nested URL is decoded, redacted and re-encoded', () {
    final inner = Uri.encodeComponent('https://x/?code=SECRET&page=2');
    final redacted = ApiLoggingInterceptor.redactUrl(
      'https://h/cb?redirect=$inner&lang=en',
    );

    expect(redacted, isNot(contains('SECRET')));
    expect(
      Uri.decodeComponent(redacted.split('redirect=')[1].split('&lang')[0]),
      'https://x/?code=***REDACTED***&page=2',
    );
    expect(redacted, endsWith('&lang=en'));
  });

  test('an encoded value without a nested secret is kept byte for byte', () {
    const url = 'https://h/cb?redirect=https%3A%2F%2Fx%2F%3Fpage%3D2';

    expect(ApiLoggingInterceptor.redactUrl(url), url);
  });

  test('a long query of secrets is redacted in linear time', () {
    final query = List.filled(40000, 'token=abcdef').join('&');
    final watch = Stopwatch()..start();

    final redacted = ApiLoggingInterceptor.redactUrl('https://h/p?$query');

    watch.stop();
    expect(redacted, isNot(contains('abcdef')));
    // Linear is tens of milliseconds; the quadratic scan took tens of
    // seconds at this size.
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  // An encoded nested URL holding one non-UTF-8 escape made the decode throw,
  // and the pass skipped the whole value, credential included.
  test('an undecodable nested URL is redacted whole, not skipped', () {
    final redacted = ApiLoggingInterceptor.redactUrl(
      '/a?redirect=https%3A%2F%2Fx%2F%3Fname%3Dcaf%E9%26token%3Dsecret&lang=en',
    );

    expect(redacted, isNot(contains('secret')));
    expect(redacted, '/a?redirect=***REDACTED***&lang=en');
  });
}
