// Lightweight boundary contract file; repetitive per-member docs are omitted.
// ignore_for_file: public_member_api_docs

/// Generic state snapshot contract for controller boundaries.
abstract class ControllerStateSnapshot {}

/// Generic auth state snapshot contract.
abstract class AuthStateSnapshot implements ControllerStateSnapshot {
  bool get isLoading;
  String? get error;
  bool get isAuthenticated;
}

/// Generic tasks state snapshot contract.
abstract class TasksStateSnapshot implements ControllerStateSnapshot {
  bool get isLoading;
  String? get error;
}

/// State boundary for authentication orchestration.
abstract class IAuthController {
  AuthStateSnapshot get snapshot;
  Future<void> login(String email, String password);
  Future<void> register(String email, String password, String name);
  Future<void> logout();
  Future<void> refreshToken();
  Future<void> getCurrentUser();
  Future<bool> isAuthenticated();
}

/// State boundary for tasks orchestration.
abstract class ITasksController {
  TasksStateSnapshot get snapshot;
  Future<void> loadTasks();
  Future<void> createTask({required String title, String? description});
  Future<void> toggleTaskCompletion(String taskId);
  Future<void> deleteTask(String taskId);
  Future<void> clearError();
}
