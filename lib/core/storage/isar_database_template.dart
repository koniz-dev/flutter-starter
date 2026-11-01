// TEMPLATE: Opt-in local DB; replace usage of no-op/local persistence when ready.
import 'package:flutter_starter/core/storage/local_database.dart';

// To enable this Isar local database:
// 1. Run: flutter pub add isar_community isar_community_flutter_libs
// 2. Run: flutter pub add --dev isar_community_generator
// 3. Uncomment the imports and code below, and list your collection schemas
//    in Isar.open (a class annotated `@collection` in a file with
//    `part '<file>.g.dart';`, then run
//    `dart run build_runner build --delete-conflicting-outputs`).
//
// These are the community-maintained Isar 3 packages. The original `isar` /
// `isar_generator` 3.x packages cannot be added to this project: their
// generator needs `source_gen` 1.x, and `freezed` 4 needs `source_gen` 3 or
// later, so `pub add` fails version solving.
//
// import 'package:isar_community/isar.dart';
// import 'package:path_provider/path_provider.dart';

/// A template implementation of `ILocalDatabase` utilizing Isar.
///
/// Opt-in: nothing binds `ILocalDatabase` by default, and the starter takes
/// on no database dependency until you follow the steps above.
class IsarDatabaseTemplate implements ILocalDatabase {
  // late Isar _isar;

  @override
  Future<void> init() async {
    // final dir = await getApplicationDocumentsDirectory();
    // _isar = await Isar.open(
    //   [
    //     // Your collection schemas, e.g. NoteSchema.
    //   ],
    //   directory: dir.path,
    // );
  }

  @override
  Future<void> save<T>(T object) async {
    // await _isar.writeTxn(() async {
    //   await _isar.collection<T>().put(object);
    // });
  }

  @override
  Future<void> saveAll<T>(List<T> objects) async {
    // await _isar.writeTxn(() async {
    //   await _isar.collection<T>().putAll(objects);
    // });
  }

  @override
  Future<List<T>> getAll<T>() async {
    // return await _isar.collection<T>().where().findAll();
    return [];
  }

  @override
  Future<T?> getById<T>(int id) async {
    // return await _isar.collection<T>().get(id);
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
