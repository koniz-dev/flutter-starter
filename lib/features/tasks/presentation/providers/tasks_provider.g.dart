// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tasks provider (Riverpod Generator).

@ProviderFor(TasksNotifier)
const tasksProvider = TasksNotifierProvider._();

/// Tasks provider (Riverpod Generator).
final class TasksNotifierProvider
    extends $NotifierProvider<TasksNotifier, TasksState> {
  /// Tasks provider (Riverpod Generator).
  const TasksNotifierProvider._()
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

String _$tasksNotifierHash() => r'b438dbd4387edb79136d65e435da3a54632644fc';

/// Tasks provider (Riverpod Generator).

abstract class _$TasksNotifier extends $Notifier<TasksState> {
  TasksState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<TasksState, TasksState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TasksState, TasksState>,
              TasksState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
