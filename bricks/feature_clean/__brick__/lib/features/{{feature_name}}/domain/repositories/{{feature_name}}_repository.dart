import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';

abstract interface class {{class_name}}Repository {
  Future<Result<{{class_name}}Entity>> getById(String id);
}

