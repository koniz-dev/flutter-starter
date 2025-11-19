import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Task detail/edit screen
class TaskDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [TaskDetailScreen] widget
  const TaskDetailScreen({
    super.key,
    this.taskId,
  });

  /// Optional task ID for editing existing task
  final String? taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final GlobalKey<FormState> _formKey;
  Task? _task;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _formKey = GlobalKey<FormState>();
    if (widget.taskId != null) {
      unawaited(_loadTask());
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    if (widget.taskId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final getTaskByIdUseCase = ref.read(getTaskByIdUseCaseProvider);
    final result = await getTaskByIdUseCase(widget.taskId!);

    result.when(
      success: (task) {
        setState(() {
          _task = task;
          _isLoading = false;
          if (task != null) {
            _titleController.text = task.title;
            _descriptionController.text = task.description ?? '';
          } else {
            _error = 'Task not found';
          }
        });
      },
      failureCallback: (failure) {
        setState(() {
          _isLoading = false;
          _error = failure.message;
        });
      },
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final tasksNotifier = ref.read(tasksNotifierProvider.notifier);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (_task != null) {
      // Update existing task
      final updatedTask = _task!.copyWith(
        title: title,
        description: description.isEmpty ? null : description,
        updatedAt: DateTime.now(),
      );
      await tasksNotifier.updateTask(updatedTask);
    } else {
      // Create new task
      await tasksNotifier.createTask(
        title: title,
        description: description.isEmpty ? null : description,
      );
    }

    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tasksState = ref.watch(tasksNotifierProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.taskId != null ? l10n.editTask : l10n.addTask),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.error),
        ),
        body: Center(
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
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (widget.taskId != null) {
                    unawaited(_loadTask());
                  } else if (context.canPop()) {
                    context.pop();
                  }
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId != null ? l10n.editTask : l10n.addTask),
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
            icon: const Icon(Icons.save),
            onPressed: tasksState.isLoading ? null : _saveTask,
            tooltip: l10n.save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.taskTitle,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.taskTitleRequired;
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.taskDescription,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              textInputAction: TextInputAction.newline,
            ),
            if (_task != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.taskDetails,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        l10n.taskStatus,
                        _task!.isCompleted ? l10n.completed : l10n.incomplete,
                        Icons.check_circle,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        l10n.createdAt,
                        _formatDateTime(_task!.createdAt),
                        Icons.calendar_today,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        l10n.updatedAt,
                        _formatDateTime(_task!.updatedAt),
                        Icons.update,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
