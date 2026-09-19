import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/datasources/{{feature_name}}_remote_datasource.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/models/{{feature_name}}_model.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/repositories/{{feature_name}}_repository.dart';

/// Default [{{class_name}}Repository] implementation.
final class {{class_name}}RepositoryImpl implements {{class_name}}Repository {
  /// Creates a [{{class_name}}RepositoryImpl].
  const {{class_name}}RepositoryImpl({required this.remoteDataSource});

  /// Source of raw {{class_name}} data.
  final {{class_name}}RemoteDataSource remoteDataSource;

  @override
  Future<Result<{{class_name}}Entity>> getById(String id) async {
    try {
      final json = await remoteDataSource.fetchById(id);
      return Success({{class_name}}Model.fromJson(json).toEntity());
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
}
