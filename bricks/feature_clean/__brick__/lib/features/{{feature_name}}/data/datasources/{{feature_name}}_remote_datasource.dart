/// Remote source of raw {{class_name}} data.
///
/// Implement this against `ApiClient` (see lib/core/network/), then
/// override the provider declared in the feature's `di/` directory.
abstract interface class {{class_name}}RemoteDataSource {
  /// Fetches the raw JSON for [id].
  Future<Map<String, dynamic>> fetchById(String id);
}
