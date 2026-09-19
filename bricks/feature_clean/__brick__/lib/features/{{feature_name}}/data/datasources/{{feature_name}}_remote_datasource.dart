/// Remote source of raw {{class_name}} data.
///
/// Implement this against `ApiClient` (see lib/core/network/), then
/// override the provider declared in the feature's `di/` directory.
// Scaffolds start with one method; drop the ignore once a second one lands.
// ignore: one_member_abstracts
abstract interface class {{class_name}}RemoteDataSource {
  /// Fetches the raw JSON for [id].
  Future<Map<String, dynamic>> fetchById(String id);
}
