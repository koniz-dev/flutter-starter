import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';
import 'package:flutter_starter/core/security/noop_rasp_service.dart';

/// Provider for the [IRaspService]. By default it relies on a no-op
/// uncoupled implementation and can be overridden in `main.dart`.
final raspServiceProvider = Provider<IRaspService>((ref) {
  return NoOpRaspService();
});
