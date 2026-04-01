import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/datasources/{{feature_name}}_remote_datasource.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/models/{{feature_name}}_model.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/repositories/{{feature_name}}_repository.dart';

final class {{class_name}}RepositoryImpl implements {{class_name}}Repository {
  const {{class_name}}RepositoryImpl({
    required this.remoteDataSource,
  });

  final {{class_name}}RemoteDataSource remoteDataSource;

  @override
  Future<Result<{{class_name}}Entity>> getById(String id) async {
    try {
      final json = await remoteDataSource.fetchById(id);
      final model = {{class_name}}Model.fromJson(json);
      return Success(model.toEntity());
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
}

