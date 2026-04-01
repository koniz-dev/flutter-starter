import 'package:flutter_starter/core/network/graphql_client_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GraphQLClient Template Tests', () {
    late GraphQLClientTemplate client;

    setUp(() {
      client = GraphQLClientTemplate();
    });

    test('should construct successfully', () {
      expect(client, isNotNull);
    });

    test('calls init gracefully', () {
      Future<String?> mockGetAuthToken() async => 'test_token';
      expect(
        () => client.init('https://api.test', mockGetAuthToken),
        returnsNormally,
      );
    });

    test('returns null for query', () async {
      final result = await client.query('query { test }', variables: {'id': 1});
      expect(result, isNull);
    });

    test('returns null for mutate', () async {
      final result = await client.mutate(
        'mutation { test }',
        variables: {'id': 1},
      );
      expect(result, isNull);
    });
  });
}
