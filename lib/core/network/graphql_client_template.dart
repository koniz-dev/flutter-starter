// TEMPLATE: Not wired into the default app; copy/adapt when adding GraphQL.
//
// IMPORTANT: To enable GraphQL support
// 1. Run: flutter pub add graphql_flutter
// 2. Uncomment the import below
// import 'package:graphql_flutter/graphql_flutter.dart';

/// An interface for GraphQL Client
abstract class IGraphQLClient {
  /// Performs a GraphQL Query
  Future<dynamic> query(String document, {Map<String, dynamic>? variables});

  /// Performs a GraphQL Mutation
  Future<dynamic> mutate(String document, {Map<String, dynamic>? variables});
}

/// A Template for setting up a production-ready GraphQL client.
/// This matches the Clean Architecture approach already using `Dio`.
class GraphQLClientTemplate implements IGraphQLClient {
  // late final GraphQLClient _client;

  // Example initialized from the DI container passing an Auth Token Getter
  /// Initializes the GraphQL client with the given endpoint and token getter.
  void init(String endpoint, Future<String?> Function() getAuthToken) {
    /*
    final httpLink = HttpLink(endpoint);

    final authLink = AuthLink(
      getToken: () async {
        final token = await getAuthToken();
        return token != null ? 'Bearer $token' : null;
      },
    );

    final link = authLink.concat(httpLink);

    _client = GraphQLClient(
      cache: GraphQLCache(store: HiveStore()),
      link: link,
    );
    */
  }

  @override
  Future<dynamic> query(
    String document, {
    Map<String, dynamic>? variables,
  }) async {
    /*
    final options = QueryOptions(
      document: gql(document),
      variables: variables ?? {},
    );

    final result = await _client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data;
    */
    return null;
  }

  @override
  Future<dynamic> mutate(
    String document, {
    Map<String, dynamic>? variables,
  }) async {
    /*
    final options = MutationOptions(
      document: gql(document),
      variables: variables ?? {},
    );

    final result = await _client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data;
    */
    return null;
  }
}
