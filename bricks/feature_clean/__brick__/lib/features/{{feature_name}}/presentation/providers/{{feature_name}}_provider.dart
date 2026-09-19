import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/{{feature_name}}/di/{{feature_name}}_providers.dart';
import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';

/// UI state for the {{class_name}} screen.
final {{class_name.camelCase()}}StateProvider =
    NotifierProvider<{{class_name}}Notifier, AsyncValue<{{class_name}}Entity?>>(
      {{class_name}}Notifier.new,
    );

/// Loads a {{class_name}} for the screen.
final class {{class_name}}Notifier extends Notifier<AsyncValue<{{class_name}}Entity?>> {
  @override
  AsyncValue<{{class_name}}Entity?> build() => const AsyncData(null);

  /// Loads the {{class_name}} identified by [id].
  Future<void> load(String id) async {
    state = const AsyncLoading();
    final result = await ref.read(get{{class_name}}ByIdUseCaseProvider)(id);
    state = result.when(
      success: AsyncData.new,
      failureCallback: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}
