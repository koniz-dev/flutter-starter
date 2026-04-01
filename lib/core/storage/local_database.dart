/// Abstract interface for relational/document database operations.
///
/// This is intended for Advanced Offline Data logic (Lists, Queries, Sync).
/// For simple string/int pair, stick to `IStorageService`.
abstract class ILocalDatabase {
  /// Initialize or open the database connection
  Future<void> init();

  /// Save a single model/document
  Future<void> save<T>(T object);

  /// Save a list of models/documents
  Future<void> saveAll<T>(List<T> objects);

  /// Retrieve all objects of type T
  Future<List<T>> getAll<T>();

  /// Retreive a single object by its primary key
  Future<T?> getById<T>(int id);

  /// Delete an object by its primary key
  Future<bool> delete<T>(int id);

  /// Clears the entire table/collection for type T
  Future<void> clear<T>();

  /// Close connection
  Future<void> close();
}
