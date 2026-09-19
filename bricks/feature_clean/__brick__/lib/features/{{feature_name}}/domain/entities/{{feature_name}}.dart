import 'package:equatable/equatable.dart';

/// Domain entity for the {{class_name}} feature.
final class {{class_name}}Entity extends Equatable {
  /// Creates a [{{class_name}}Entity] with the given [id].
  const {{class_name}}Entity({required this.id});

  /// Stable identifier of this {{class_name}}.
  final String id;

  @override
  List<Object?> get props => [id];
}
