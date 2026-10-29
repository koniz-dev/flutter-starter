import 'dart:math';

import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('structured fuzz: userinfo Uri.parse sees never survives redactUrl', () {
    final random = Random(8692);
    String pick(List<String> xs) => xs[random.nextInt(xs.length)];
    const schemes = ['', 'ws:', 'wss:', 'WS:', 'http:', 'a+b.c-d:'];
    const seps = ['//', r'\\', r'/\', r'\/', '/', r'\', ''];
    const infoChars = [
      'u', 'p', ':', '%2f', '%2F', '%41', '%40', 'é', ' ', "'", '!', r'$',
      '&', '=', '+', ';', ',', '*', '(', ')', '~', '.', '-', '_', '@',
    ];
    const hosts = ['h', '127.0.0.1', '[::1]', 'h:8080', 'xn--d', ''];
    const tails = ['', '/', '/s', '?token=T', '#f', r'\s', '/a@b', '?m=a@b'];
    var withUserInfo = 0;
    final misses = <String>[];
    var throws = 0;
    for (var n = 0; n < 300000; n++) {
      final info = List.generate(
        1 + random.nextInt(6),
        (_) => pick(infoChars),
      ).join();
      final url =
          '${pick(schemes)}${pick(seps)}$info@${pick(hosts)}${pick(tails)}';
      final before = Uri.tryParse(url);
      if (before == null || before.userInfo.isEmpty) continue;
      withUserInfo++;
      String redacted;
      try {
        redacted = ApiLoggingInterceptor.redactUrl(url);
      } on Object {
        throws++;
        continue;
      }
      final leftover = Uri.tryParse(redacted)?.userInfo ?? '';
      if (leftover.isNotEmpty &&
          Uri.decodeComponent(leftover) != '***REDACTED***') {
        if (misses.length < 10) misses.add('$url -> $redacted [$leftover]');
      }
    }
    // ignore: avoid_print
    print('urls with userinfo: $withUserInfo, throws: $throws, '
        'misses: ${misses.length}');
    // ignore: avoid_print
    misses.forEach(print);
    expect(throws, 0);
    expect(misses, isEmpty);
  });
}
