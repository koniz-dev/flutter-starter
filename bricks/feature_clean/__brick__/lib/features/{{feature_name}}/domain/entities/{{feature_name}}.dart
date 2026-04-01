import 'package:equatable/equatable.dart';

/// Domain entity for the {{class_name}} feature.
final class {{class_name}}Entity extends Equatable {
  const {{class_name}}Entity({
    required this.id,
  });

  final String id;

  @override
  List<Object?> get props => [id];
}

