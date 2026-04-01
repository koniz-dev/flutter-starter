// TEMPLATE: Opt-in local DB; replace usage of no-op/local persistence when ready.
import 'package:flutter_starter/core/storage/local_database.dart';

// IMPORTANT: To enable this Isar Local Database:
// 1. Run: flutter pub add isar isar_flutter_libs
// 2. Run: flutter pub add --dev isar_generator
// 3. Uncomment all imports below to activate
// import 'package:isar/isar.dart';
// import 'package:path_provider/path_provider.dart';

/// A template implementation of `ILocalDatabase` utilizing Isar.
///
/// `Isar` is highly performant and the recommended NoSQL DB for Flutter Apps.
class IsarDatabaseTemplate implements ILocalDatabase {
  // late Isar _isar;

  @override
  Future<void> init() async {
    // Uncomment initialization code when Isar is activated:
    /*
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        // Add your Isar Collection Schemas here:
        // UserSchema, TaskSchema...
      ],
      directory: dir.path,
    );
    */
  }

  @override
  Future<void> save<T>(T object) async {
    // await _isar.writeTxn(() async {
    //   await _isar.collection<T>().put(object as dynamic);
    // });
  }

  @override
  Future<void> saveAll<T>(List<T> objects) async {
    // await _isar.writeTxn(() async {
    //   await _isar.collection<T>().putAll(objects as List<dynamic>);
    // });
  }

  @override
  Future<List<T>> getAll<T>() async {
    // return _isar.collection<T>().where().findAll();
    return [];
  }

  @override
  Future<T?> getById<T>(int id) async {
    // return _isar.collection<T>().get(id);
    return null;
  }

  @override
  Future<bool> delete<T>(int id) async {
    // var deleted = false;
    // await _isar.writeTxn(() async {
    //   deleted = await _isar.collection<T>().delete(id);
    // });
    // return deleted;
    return false;
  }

  @override
  Future<void> clear<T>() async {
    // await _isar.writeTxn(() async {
    //   await _isar.collection<T>().clear();
    // });
  }

  @override
  Future<void> close() async {
    // await _isar.close();
  }
}
