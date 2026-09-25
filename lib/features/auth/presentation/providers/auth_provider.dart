import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.freezed.dart';
part 'auth_provider.g.dart';

/// Authentication state
@freezed
abstract class AuthState with _$AuthState {
  /// Creates an [AuthState] with the given [user], [isLoading], and [error]
  const factory AuthState({
    /// Currently authenticated user, null if not logged in
    User? user,

    /// Whether an authentication operation is in progress
    @Default(false) bool isLoading,

    /// Error message if authentication failed, null otherwise
    String? error,
  }) = _AuthState;
}

/// Snapshot adapter for exposing auth state through boundary contracts.
class RiverpodAuthStateSnapshot implements AuthStateSnapshot {
  /// Adapts the Riverpod [AuthState] to the boundary snapshot contract.
  const RiverpodAuthStateSnapshot(this._state);

  final AuthState _state;

  @override
  bool get isLoading => _state.isLoading;

  @override
  String? get error => _state.error;

  @override
  bool get isAuthenticated => _state.user != null;
}

/// Authentication provider (Riverpod 3.0 - using Notifier)
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier implements IAuthController {
  @override
  AuthStateSnapshot get snapshot => RiverpodAuthStateSnapshot(state);

  @override
  AuthState build() => const AuthState();

  /// Attempts to login with the given [email] and [password]
  @override
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final loginUseCase = ref.read(loginUseCaseProvider);
    final result = await loginUseCase(email, password);

    result.when(
      success: (user) {
        state = state.copyWith(user: user, isLoading: false, error: null);
      },
      failureCallback: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  /// Attempts to register a new user with [email], [password], and [name]
  @override
  Future<void> register(String email, String password, String name) async {
    state = state.copyWith(isLoading: true, error: null);

    final registerUseCase = ref.read(registerUseCaseProvider);
    final result = await registerUseCase(email, password, name);

    result.when(
      success: (user) {
        state = state.copyWith(user: user, isLoading: false, error: null);
      },
      failureCallback: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  /// Logs out the current user.
  ///
  /// The session is dropped on **both** paths. `AuthRepository.logout()` tears
  /// the local session down unconditionally - tokens and cached user - and only
  /// then reports whether the server was told, so keeping `state.user` on the
  /// failure path left the app showing an authenticated UI with no credentials
  /// behind it and no way back to `/login`. The failure message is still
  /// surfaced, so the user learns the server was not reached.
  @override
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);

    final logoutUseCase = ref.read(logoutUseCaseProvider);
    final result = await logoutUseCase();

    result.when(
      success: (_) {
        state = const AuthState();
      },
      failureCallback: (failure) {
        state = AuthState(error: failure.message);
      },
    );
  }

  /// Drops the in-memory session, without touching persisted state.
  ///
  /// The counterpart to [logout] for a session the user did not end: the
  /// transport already cleared the tokens, the cached user and the response
  /// cache before calling this, so repeating that work here - or calling the
  /// logout endpoint, which would post credentials that no longer exist -
  /// would be wrong.
  ///
  /// Resets to the initial state rather than only nulling `user`: a forced
  /// logout can land mid-flight, and leaving `isLoading` true would spin a
  /// screen forever over a session that no longer exists. `error` is left null
  /// on purpose - the caller's own failed request surfaces its error, and the
  /// router is about to replace this screen with `/login` regardless.
  void clearSession() {
    state = const AuthState();
  }

  /// Refreshes the authentication token
  ///
  /// This is typically called automatically by the AuthInterceptor,
  /// but can be called manually if needed.
  @override
  Future<void> refreshToken() async {
    final refreshTokenUseCase = ref.read(refreshTokenUseCaseProvider);
    final result = await refreshTokenUseCase();

    await result.when(
      success: (_) async {
        // Token refreshed successfully, no state change needed
        // The token is stored in secure storage by the repository
      },
      failureCallback: (failure) async {
        // Refresh failed, might need to logout
        // Check if it's a refresh token expiry error
        if (failure.code == 'REFRESH_TOKEN_EXPIRED' ||
            failure.message.toLowerCase().contains('refresh')) {
          await logout();
        }
      },
    );
  }

  /// Gets the current authenticated user
  @override
  Future<void> getCurrentUser() async {
    state = state.copyWith(isLoading: true, error: null);

    final getCurrentUserUseCase = ref.read(getCurrentUserUseCaseProvider);
    final result = await getCurrentUserUseCase();

    result.when(
      success: (user) {
        state = state.copyWith(user: user, isLoading: false, error: null);
      },
      failureCallback: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  /// Restores a session persisted by a previous run of the app.
  ///
  /// `build()` is synchronous and cannot read storage, so a cold start begins
  /// unauthenticated even when `login()` cached a user and tokens. This reads
  /// the cached user back and promotes the state to authenticated.
  ///
  /// A restore that finds nothing - or fails outright - is not a user-facing
  /// error: it just means there is no session to resume, so the state is left
  /// unauthenticated and `error` stays null rather than greeting a first-time
  /// user with a failure message on the login screen.
  ///
  /// Never throws. Storage can fail in ways the data layer does not model as
  /// an `Exception` (a missing platform plugin, a decode `Error`), and this
  /// runs unawaited at boot, where an escaping error would be uncaught.
  ///
  /// ## What counts as a restorable session
  ///
  /// A cached user blob is **not** enough. `AuthRepository.getCurrentUser()`
  /// requires a non-empty access token as well, so a device holding a stale
  /// user blob with no credentials boots to `/login` instead of into the
  /// authenticated shell it cannot make a single request from (#85).
  ///
  /// ## Expired-but-present token: restore, do not bounce
  ///
  /// Decided here rather than left implied by the code. A token that is
  /// present but expired **restores the session**, and the 401 refresh flow
  /// deals with it. Three reasons:
  ///
  /// 1. **Expiry is not locally observable.** `ITokenStore` persists opaque
  ///    strings and no expiry metadata. Deciding "expired" would mean decoding
  ///    a JWT the contract never promises - the token may be an opaque handle
  ///    or a session id - and a wrong guess signs out a perfectly good session.
  ///    The server is the only authority on expiry, and it answers with a 401.
  /// 2. **The 401 path is now correct.** Since #59 `AuthInterceptor` refreshes
  ///    once, replays the queued requests, and on a failed refresh clears the
  ///    tokens *and* the cached user blob - exactly the state a logout leaves.
  ///    The next `getCurrentUser()` therefore returns null and the next cold
  ///    start lands on `/login`. Restoring optimistically no longer strands
  ///    anybody.
  /// 3. **Bouncing would make refresh dead code** for the population it exists
  ///    for. Access tokens are short-lived by design; a returning user's is
  ///    routinely stale. Pessimistically bouncing them discards a valid refresh
  ///    token and shows a login form to someone who did not need one.
  ///
  /// The accepted cost: a user whose refresh token is *also* dead sees one
  /// authenticated frame before the first 401 resolves. That is strictly better
  /// than a guaranteed `/login` flash for every returning user, and it is the
  /// trade #51 was about.
  Future<void> restoreSession() async {
    try {
      final getCurrentUserUseCase = ref.read(getCurrentUserUseCaseProvider);
      final result = await getCurrentUserUseCase();

      result.when(
        success: (user) {
          if (user != null) {
            state = state.copyWith(user: user, isLoading: false, error: null);
          }
        },
        failureCallback: (_) {},
      );
      // A bare catch is the point: `on Exception` would let a plugin/decode
      // Error escape into the unawaited boot path, which is precisely the
      // crash this restore must not cause.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Unrestorable session: stay logged out.
    }
  }

  /// Checks if the user is authenticated
  ///
  /// Returns true if user is authenticated, false otherwise.
  /// This method does not update the state.
  @override
  Future<bool> isAuthenticated() async {
    final isAuthenticatedUseCase = ref.read(isAuthenticatedUseCaseProvider);
    final result = await isAuthenticatedUseCase();

    return result.when(
      success: (isAuth) => isAuth,
      failureCallback: (_) => false,
    );
  }
}

/// Adapter letting `lib/core/network` end the in-memory session.
///
/// Holds a [Ref] and resolves [authNotifierProvider] only when a session is
/// actually terminated. That laziness is the whole point: it is the same trick
/// the `refreshToken` callback in `authInterceptorProvider` uses. The
/// interceptor is constructed while the provider graph is still being built -
/// `apiClientProvider` reads it - so resolving the notifier eagerly would close
/// the loop notifier -> use case -> repository -> remote data source ->
/// ApiClient -> interceptor -> notifier. Deferred to call time, the edge only
/// exists once a request has already 401'd, by which point every provider in
/// that chain is built.
class RiverpodSessionTerminationSink implements ISessionTerminationSink {
  /// Binds this sink to the container holding the session.
  const RiverpodSessionTerminationSink(this._ref);

  final Ref _ref;

  @override
  void onSessionTerminated() =>
      _ref.read(authNotifierProvider.notifier).clearSession();
}

/// Boundary provider exposing auth controller contract.
final authControllerProvider = Provider<IAuthController>((ref) {
  return ref.read(authNotifierProvider.notifier);
});

/// Restores the persisted session, once per app launch.
///
/// Three states, and every consumer has to handle all three:
/// * `loading` - storage has not answered yet, so it is **not** yet known
///   whether this is a returning user. Treating this as "logged out" is what
///   bounces a returning user to `/login` for a frame.
/// * `data` - the restore finished. [authNotifierProvider] now holds the
///   session if there was one.
/// * `error` - only reachable if a consumer replaces this provider; the
///   restore itself swallows failures (see [AuthNotifier.restoreSession]).
///
/// `main()` awaits this before `runApp`, so the first frame of a cold start
/// already has the answer. The router still handles the loading state because
/// anything that builds the router without awaiting first (widget tests, an
/// embedder) does observe the window.
final sessionRestorationProvider = FutureProvider<void>((ref) async {
  await ref.read(authNotifierProvider.notifier).restoreSession();
});

/// Backward-compatible alias for the generated provider.
///
/// Riverpod Generator shortens `AuthNotifier` -> `authProvider` by default.
/// Keep the original name as a stable API surface for app code and tests.
const AuthNotifierProvider authNotifierProvider = authProvider;
