import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/datasources/{{feature_name}}_remote_datasource.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/repositories/{{feature_name}}_repository_impl.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/repositories/{{feature_name}}_repository.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/usecases/get_{{feature_name}}_by_id_usecase.dart';

final {{feature_name}}RemoteDataSourceProvider = Provider<{{class_name}}RemoteDataSource>((ref) {
  throw UnimplementedError(
    '{{class_name}}RemoteDataSource is not wired. Provide an implementation and override {{feature_name}}RemoteDataSourceProvider.',
  );
});

final {{feature_name}}RepositoryProvider = Provider<{{class_name}}Repository>((ref) {
  final remote = ref.watch({{feature_name}}RemoteDataSourceProvider);
  return {{class_name}}RepositoryImpl(remoteDataSource: remote);
});

final get{{class_name}}ByIdUseCaseProvider = Provider<Get{{class_name}}ByIdUseCase>((ref) {
  final repo = ref.watch({{feature_name}}RepositoryProvider);
  return Get{{class_name}}ByIdUseCase(repo);
});

