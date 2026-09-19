import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/repositories/{{feature_name}}_repository.dart';

/// Loads a single [{{class_name}}Entity] by id.
final class Get{{class_name}}ByIdUseCase {
  /// Creates a [Get{{class_name}}ByIdUseCase].
  const Get{{class_name}}ByIdUseCase(this._repository);

  final {{class_name}}Repository _repository;

  /// Runs the use case for [id].
  Future<Result<{{class_name}}Entity>> call(String id) => _repository.getById(id);
}
