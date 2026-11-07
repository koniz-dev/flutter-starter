import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'opt-in template retains pinning, HTTPS refusal and memory-only cache',
    () {
      final source = File('lib/core/network/graphql_client_template.dart')
          .readAsStringSync();
      final init = source.split('void init(').last.split('*/').first;
      for (final required in [
        'SslPinning.fromConfig()',
        'pinning.isMisconfigured',
        'IOClient(pinning.createHttpClient())',
        'kReleaseMode',
        'AppConfig.isStaging || AppConfig.isProduction',
        "endpointUri.scheme.toLowerCase() != 'https'",
        'GraphQLCache(store: InMemoryStore())',
      ]) {
        expect(init, contains(required), reason: required);
      }
      expect(source, isNot(contains('HiveStore(')));
      final docs = File('docs/api/core/network.md').readAsStringSync();
      expect(docs, contains('no token\nrefresh, 401 replay, or forced logout'));
      expect(docs, contains('one client/cache per session'));
    },
  );
}
