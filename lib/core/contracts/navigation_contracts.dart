// Lightweight boundary contract file; repetitive per-member docs are omitted.
// ignore_for_file: public_member_api_docs

/// Framework-agnostic navigation intents.
abstract class AppNavigator {
  Future<void> toHome();
  Future<void> toLogin();
  Future<void> toRegister();
  Future<void> toTasks();
  Future<void> toTaskDetail(String taskId);

  Future<void> push(String location, {Object? extra});
  Future<void> replace(String location, {Object? extra});
  Future<void> back<T>([T? result]);
}
