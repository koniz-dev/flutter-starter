import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/{{feature_name}}/presentation/providers/{{feature_name}}_provider.dart';

class {{class_name}}Screen extends ConsumerWidget {
  const {{class_name}}Screen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({{feature_name}}StateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('{{class_name}}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          data: (entity) => Text(entity?.id ?? 'Not loaded'),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error: $err'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read({{feature_name}}StateProvider.notifier).load(id),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

