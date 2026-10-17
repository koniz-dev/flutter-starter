import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_extensions.dart';
import 'package:flutter_starter/features/{{feature_name}}/presentation/providers/{{feature_name}}_provider.dart';

/// Screen showing a single {{class_name}}.
class {{class_name}}Screen extends ConsumerWidget {
  /// Creates a [{{class_name}}Screen] for [id].
  const {{class_name}}Screen({required this.id, super.key});

  /// Identifier of the {{class_name}} to display.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({{class_name.camelCase()}}StateProvider);

    return Scaffold(
      // l10n-literal-ok: generated placeholder - add an ARB key for the title
      appBar: AppBar(title: const Text('{{class_name}}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          data: (entity) => Text(entity?.id ?? 'Not loaded'),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('${context.l10n.error}: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read({{class_name.camelCase()}}StateProvider.notifier).load(id),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
