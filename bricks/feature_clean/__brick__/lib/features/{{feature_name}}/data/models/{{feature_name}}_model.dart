import 'package:flutter_starter/features/{{feature_name}}/domain/entities/{{feature_name}}.dart';

final class {{class_name}}Model {
  const {{class_name}}Model({
    required this.id,
  });

  factory {{class_name}}Model.fromJson(Map<String, dynamic> json) {
    return {{class_name}}Model(
      id: (json['id'] ?? '').toString(),
    );
  }

  final String id;

  {{class_name}}Entity toEntity() => {{class_name}}Entity(id: id);
}

