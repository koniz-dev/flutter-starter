import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';

/// Data-layer representation of a {{class_name}}.
final class {{class_name}}Model {
  /// Creates a [{{class_name}}Model] with the given [id].
  const {{class_name}}Model({required this.id});

  /// Builds a [{{class_name}}Model] from decoded [json].
  factory {{class_name}}Model.fromJson(Map<String, dynamic> json) {
    return {{class_name}}Model(id: (json['id'] ?? '').toString());
  }

  /// Stable identifier of this {{class_name}}.
  final String id;

  /// Converts this model into its domain entity.
  {{class_name}}Entity toEntity() => {{class_name}}Entity(id: id);
}
