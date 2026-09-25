import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/session/session_generation.dart';

/// The app's single [SessionGeneration].
///
/// Must be one instance for the whole container: `AuthInterceptor` reads it to
/// decide whether a finished refresh may still write, and `AuthRepositoryImpl`
/// both reads it (in `refreshToken`) and advances it (in `login`, `register`
/// and `logout`). Two instances would let each side believe the session it is
/// holding is still live, which is exactly the state
/// koniz-dev/flutter-starter#169 describes.
final sessionGenerationProvider = Provider<SessionGeneration>((ref) {
  return SessionGeneration();
});
