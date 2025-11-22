# Tasks Feature

A complete CRUD (Create, Read, Update, Delete) example feature demonstrating Clean Architecture patterns, local storage, and integration with all template capabilities.

## Overview

The Tasks feature provides a simple but realistic task management system that showcases:

- **Clean Architecture**: Complete implementation across Domain, Data, and Presentation layers
- **CRUD Operations**: Create, read, update, delete, and toggle completion
- **Local Storage**: Persistent data using `StorageService` (SharedPreferences)
- **State Management**: Riverpod Notifier pattern for reactive state
- **Navigation**: List/detail flow with go_router
- **i18n Support**: Full internationalization (English, Spanish, Arabic)
- **Feature Flags**: Integration with feature flags system
- **Error Handling**: Result pattern for type-safe error handling
- **Testing**: Unit and widget test examples

## Architecture

```
┌─────────────────────────────────────┐
│   Presentation Layer                │
│   - TasksListScreen                 │
│   - TaskDetailScreen                │
│   - TasksNotifier (Riverpod)        │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Domain Layer                      │
│   - Task Entity                     │
│   - TasksRepository Interface       │
│   - Use Cases (GetAll, GetById,     │
│     Create, Update, Delete, Toggle) │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Data Layer                        │
│   - TaskModel                       │
│   - TasksLocalDataSource            │
│   - TasksRepositoryImpl             │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Core Layer                        │
│   - StorageService                  │
│   - Result Pattern                  │
│   - Error Handling                  │
└─────────────────────────────────────┘
```

## File Structure

```
lib/features/tasks/
├── domain/
│   ├── entities/
│   │   └── task.dart                    # Task entity
│   ├── repositories/
│   │   └── tasks_repository.dart        # Repository interface
│   └── usecases/
│       ├── get_all_tasks_usecase.dart
│       ├── get_task_by_id_usecase.dart
│       ├── create_task_usecase.dart
│       ├── update_task_usecase.dart
│       ├── delete_task_usecase.dart
│       └── toggle_task_completion_usecase.dart
├── data/
│   ├── models/
│   │   └── task_model.dart             # Task model (extends entity)
│   ├── datasources/
│   │   └── tasks_local_datasource.dart # Local storage operations
│   └── repositories/
│       └── tasks_repository_impl.dart  # Repository implementation
└── presentation/
    ├── providers/
    │   └── tasks_provider.dart         # Riverpod state management
    └── screens/
        ├── tasks_list_screen.dart      # List view
        └── task_detail_screen.dart      # Detail/edit view
```

## Key Components

### Domain Layer

#### Task Entity
```dart
class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### Repository Interface
Defines the contract for task operations:
- `getAllTasks()` - Get all tasks
- `getTaskById(String id)` - Get a specific task
- `createTask(Task task)` - Create a new task
- `updateTask(Task task)` - Update an existing task
- `deleteTask(String id)` - Delete a task
- `toggleTaskCompletion(String id)` - Toggle completion status

#### Use Cases
Each business operation is encapsulated in a use case:
- `GetAllTasksUseCase`
- `GetTaskByIdUseCase`
- `CreateTaskUseCase`
- `UpdateTaskUseCase`
- `DeleteTaskUseCase`
- `ToggleTaskCompletionUseCase`

### Data Layer

#### TaskModel
Extends the `Task` entity and provides JSON serialization:
```dart
class TaskModel extends Task {
  TaskModel.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  Task toEntity();
}
```

#### TasksLocalDataSource
Handles local storage operations using `StorageService`:
- Stores tasks as JSON in SharedPreferences
- Provides CRUD operations for task persistence

#### TasksRepositoryImpl
Implements the repository interface:
- Coordinates between use cases and data sources
- Maps exceptions to failures using `ExceptionToFailureMapper`
- Returns `Result<T>` for type-safe error handling

### Presentation Layer

#### TasksNotifier
Riverpod Notifier managing tasks state:
```dart
class TasksState {
  final List<Task> tasks;
  final bool isLoading;
  final String? error;
}
```

Methods:
- `refresh()` - Reload all tasks
- `createTask()` - Create a new task
- `updateTask()` - Update an existing task
- `deleteTask()` - Delete a task
- `toggleTaskCompletion()` - Toggle completion status

#### TasksListScreen
Main screen displaying:
- List of incomplete tasks
- List of completed tasks
- Empty state when no tasks
- Error state with retry option
- Pull-to-refresh support
- Floating action button to add tasks

#### TaskDetailScreen
Screen for viewing/editing tasks:
- Form for title and description
- Task metadata (status, created/updated dates)
- Save functionality
- Supports both create and edit modes

## Usage

### Navigation

```dart
// Navigate to tasks list
context.goToTasks();

// Navigate to task detail
context.goToTaskDetail(taskId);

// Using route constants
context.pushRoute('${AppRoutes.tasks}/$taskId');
```

### Using the Provider

```dart
// Watch tasks state
final tasksState = ref.watch(tasksNotifierProvider);

// Read notifier for actions
final notifier = ref.read(tasksNotifierProvider.notifier);
await notifier.createTask(title: 'New Task', description: 'Description');
await notifier.toggleTaskCompletion(taskId);
await notifier.deleteTask(taskId);
```

### Feature Flag Integration

The tasks feature can be controlled via feature flag:

```dart
FeatureFlagWidget(
  flag: FeatureFlags.tasks,
  child: TasksListScreen(),
)
```

## Integration Points

### 1. Storage Service
Uses `StorageService` for local persistence:
- Tasks stored as JSON in SharedPreferences
- Key: `tasks_data`
- Automatic serialization/deserialization

### 2. Routing
Integrated with go_router:
- Route: `/tasks` - List screen
- Route: `/tasks/:taskId` - Detail screen
- Navigation extensions: `goToTasks()`, `goToTaskDetail()`

### 3. Internationalization
All strings are localized:
- English (en)
- Spanish (es)
- Arabic (ar)

### 4. Error Handling
Uses Result pattern:
```dart
result.when(
  success: (tasks) => handleSuccess(tasks),
  failureCallback: (failure) => handleError(failure),
);
```

### 5. Logging
Logging is handled automatically by the repository layer through exception mapping.

## Testing

### Unit Tests

Tests are organized by layer:

```
test/features/tasks/
├── domain/
│   ├── usecases/
│   │   ├── get_all_tasks_usecase_test.dart
│   │   ├── create_task_usecase_test.dart
│   │   └── ...
│   └── entities/
│       └── task_test.dart
├── data/
│   ├── datasources/
│   │   └── tasks_local_datasource_test.dart
│   ├── repositories/
│   │   └── tasks_repository_impl_test.dart
│   └── models/
│       └── task_model_test.dart
└── presentation/
    ├── providers/
    │   └── tasks_provider_test.dart
    └── screens/
        ├── tasks_list_screen_test.dart
        └── task_detail_screen_test.dart
```

### Example Test Structure

```dart
void main() {
  group('CreateTaskUseCase', () {
    late CreateTaskUseCase useCase;
    late MockTasksRepository mockRepository;

    setUp(() {
      mockRepository = MockTasksRepository();
      useCase = CreateTaskUseCase(mockRepository);
    });

    test('should create task successfully', () async {
      // Arrange
      final task = Task(id: '1', title: 'Test');
      when(() => mockRepository.createTask(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      final result = await useCase(title: 'Test');

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.createTask(any())).called(1);
    });
  });
}
```

## Patterns Demonstrated

1. **Clean Architecture**: Clear separation of concerns across layers
2. **Repository Pattern**: Abstraction over data sources
3. **Use Case Pattern**: Business logic encapsulation
4. **Result Pattern**: Type-safe error handling
5. **Dependency Injection**: Riverpod providers
6. **State Management**: Riverpod Notifier pattern
7. **Local Storage**: SharedPreferences integration
8. **Navigation**: go_router with type-safe routes
9. **Internationalization**: Multi-language support
10. **Feature Flags**: Conditional feature enabling

## Future Enhancements

Potential improvements:
- Remote data source (API integration)
- Task categories/tags
- Task priorities
- Due dates
- Search and filtering
- Sorting options
- Bulk operations
- Task sharing
- Offline sync

## See Also

- [Clean Architecture Guide](../architecture/overview.md)
- [Routing Guide](../guides/features/routing-guide.md)
- [Feature Flags Guide](../features/feature-flags.md)
- [Internationalization Guide](../guides/features/internationalization-guide.md)

