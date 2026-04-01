import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/di/{{feature_name}}_providers.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';

final {{feature_name}}StateProvider =
    NotifierProvider<{{class_name}}Notifier, AsyncValue<{{class_name}}Entity?>>(
  {{class_name}}Notifier.new,
);

final class {{class_name}}Notifier extends Notifier<AsyncValue<{{class_name}}Entity?>> {
  @override
  AsyncValue<{{class_name}}Entity?> build() => const AsyncData(null);

  Future<void> load(String id) async {
    state = const AsyncLoading();
    final useCase = ref.read(get{{class_name}}ByIdUseCaseProvider);
    final result = await useCase(id);
    state = result.when(
      success: (entity) => AsyncData(entity),
      failureCallback: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}

