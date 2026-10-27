import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';

/// Data-layer contract for the {{class_name}} feature.
abstract interface class {{class_name}}Repository {
  /// Loads the [{{class_name}}Entity] identified by [id].
  Future<Result<{{class_name}}Entity>> getById(String id);
}
