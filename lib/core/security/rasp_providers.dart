import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';

/// Provider for the [IRaspService]. By default it relies on a no-op
/// uncoupled interface and must be overridden in `main.dart`.
final raspServiceProvider = Provider<IRaspService>((ref) {
  throw UnimplementedError(
    'raspServiceProvider must be overridden in main.dart if you want '
    'to use RASP',
  );
});
