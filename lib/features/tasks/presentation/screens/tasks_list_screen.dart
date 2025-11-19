import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// Tasks list screen
class TasksListScreen extends ConsumerWidget {
  /// Creates a [TasksListScreen] widget
  const TasksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksNotifierProvider);
    final tasksNotifier = ref.read(tasksNotifierProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tasks),
        actions: [
          if (tasksState.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: tasksState.isLoading ? null : tasksNotifier.refresh,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: tasksNotifier.refresh,
        child: _buildBody(context, tasksState, tasksNotifier, l10n),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, ref, l10n),
        tooltip: l10n.addTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TasksState state,
    TasksNotifier notifier,
    AppLocalizations l10n,
  ) {
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => notifier.refresh(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (state.tasks.isEmpty && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noTasks,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.addYourFirstTask,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final completedTasks = state.tasks.where((t) => t.isCompleted).toList();
    final incompleteTasks = state.tasks.where((t) => !t.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (incompleteTasks.isNotEmpty) ...[
          _buildSectionHeader(l10n.incompleteTasks, context),
          ...incompleteTasks.map(
            (task) => _buildTaskTile(
              context,
              task,
              notifier,
              l10n,
            ),
          ),
        ],
        if (completedTasks.isNotEmpty) ...[
          _buildSectionHeader(l10n.completedTasks, context),
          ...completedTasks.map(
            (task) => _buildTaskTile(
              context,
              task,
              notifier,
              l10n,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    Task task,
    TasksNotifier notifier,
    AppLocalizations l10n,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) => notifier.toggleTaskCompletion(task.id),
        ),
        title: Text(
          task.title,
          style: task.isCompleted
              ? const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                )
              : null,
        ),
        subtitle: task.description != null && task.description!.isNotEmpty
            ? Text(
                task.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: task.isCompleted
                    ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      )
                    : null,
              )
            : null,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              context.pushRoute(
                '${AppRoutes.tasks}/${task.id}',
              );
            } else if (value == 'delete') {
              unawaited(
                _showDeleteConfirmation(context, task, notifier, l10n),
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.edit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    l10n.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          context.pushRoute('${AppRoutes.tasks}/${task.id}');
        },
      ),
    );
  }

  Future<void> _showAddTaskDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddTaskDialogContent(
        ref: ref,
        l10n: l10n,
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    Task task,
    TasksNotifier notifier,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTask),
        content: Text(l10n.deleteTaskConfirmation(task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await notifier.deleteTask(task.id);
    }
  }
}

/// Dialog content widget that manages TextEditingController lifecycle
class _AddTaskDialogContent extends StatefulWidget {
  const _AddTaskDialogContent({
    required this.ref,
    required this.l10n,
  });

  final WidgetRef ref;
  final AppLocalizations l10n;

  @override
  State<_AddTaskDialogContent> createState() => _AddTaskDialogContentState();
}

class _AddTaskDialogContentState extends State<_AddTaskDialogContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.addTask),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: widget.l10n.taskTitle,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return widget.l10n.taskTitleRequired;
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: widget.l10n.taskDescription,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final title = _titleController.text.trim();
              final description = _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim();
              Navigator.of(context).pop();
              // Create task after dialog is closed to avoid controller issues
              unawaited(
                widget.ref.read(tasksNotifierProvider.notifier).createTask(
                      title: title,
                      description: description,
                    ),
              );
            }
          },
          child: Text(widget.l10n.add),
        ),
      ],
    );
  }
}
