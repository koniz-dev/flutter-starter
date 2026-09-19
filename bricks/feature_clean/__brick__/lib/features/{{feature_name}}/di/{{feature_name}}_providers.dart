import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/datasources/{{feature_name}}_remote_datasource.dart';
import 'package:flutter_starter/features/{{feature_name}}/data/repositories/{{feature_name}}_repository_impl.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/repositories/{{feature_name}}_repository.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/usecases/get_{{feature_name}}_by_id_usecase.dart';

/// Remote data source for the {{class_name}} feature.
///
/// Deliberately unimplemented: override this provider with a real
/// implementation in main.dart or in a test's `ProviderScope`.
final {{class_name.camelCase()}}RemoteDataSourceProvider = Provider<{{class_name}}RemoteDataSource>((
  ref,
) {
  throw UnimplementedError(
    'Override this provider with a real '
    '{{class_name}}RemoteDataSource implementation.',
  );
});

/// Repository for the {{class_name}} feature.
final {{class_name.camelCase()}}RepositoryProvider = Provider<{{class_name}}Repository>((ref) {
  return {{class_name}}RepositoryImpl(
    remoteDataSource: ref.watch({{class_name.camelCase()}}RemoteDataSourceProvider),
  );
});

/// Use case that loads one {{class_name}} by id.
final get{{class_name}}ByIdUseCaseProvider = Provider<Get{{class_name}}ByIdUseCase>((ref) {
  return Get{{class_name}}ByIdUseCase(ref.watch({{class_name.camelCase()}}RepositoryProvider));
});
