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

/// The current [SessionGeneration.current], re-evaluated every time a
/// session ends or is replaced.
///
/// Logout, forced logout, login and register all advance the generation, so a
/// feature holding per-user state - in memory or on disk - listens to this
/// and resets on every change. It is the only way to learn the user changed
/// without importing the auth slice, which features may not do
/// (koniz-dev/flutter-starter#452).
///
/// A [Notifier] rather than a `Provider` that invalidates itself: assigning
/// `state` notifies listeners synchronously, inside the `invalidate()` call,
/// whereas an invalidated provider only rebuilds when next read.
final sessionEpochProvider = NotifierProvider<SessionEpochNotifier, int>(
  SessionEpochNotifier.new,
);

/// Mirrors [SessionGeneration.current] for [sessionEpochProvider].
class SessionEpochNotifier extends Notifier<int> {
  @override
  int build() {
    final generation = ref.watch(sessionGenerationProvider);
    void onChange() => state = generation.current;
    generation.addListener(onChange);
    ref.onDispose(() => generation.removeListener(onChange));
    return generation.current;
  }
}
