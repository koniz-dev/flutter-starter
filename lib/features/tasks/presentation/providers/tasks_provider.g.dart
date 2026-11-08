// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tasks provider (Riverpod Generator).

@ProviderFor(TasksNotifier)
final tasksProvider = TasksNotifierProvider._();

/// Tasks provider (Riverpod Generator).
final class TasksNotifierProvider
    extends $NotifierProvider<TasksNotifier, TasksState> {
  /// Tasks provider (Riverpod Generator).
  TasksNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tasksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tasksNotifierHash();

  @$internal
  @override
  TasksNotifier create() => TasksNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TasksState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TasksState>(value),
    );
  }
}

String _$tasksNotifierHash() => r'2555574f27981d8f6038c1e57c151ce75ae2cc9b';

/// Tasks provider (Riverpod Generator).

abstract class _$TasksNotifier extends $Notifier<TasksState> {
  TasksState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TasksState, TasksState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TasksState, TasksState>,
              TasksState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
