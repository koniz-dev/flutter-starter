import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/repositories/{{feature_name}}_repository.dart';

final class Get{{class_name}}ByIdUseCase {
  const Get{{class_name}}ByIdUseCase(this._repository);

  final {{class_name}}Repository _repository;

  Future<Result<{{class_name}}Entity>> call(String id) {
    return _repository.getById(id);
  }
}

