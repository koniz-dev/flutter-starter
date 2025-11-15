import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_provider.freezed.dart';

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

/// Authentication provider (Riverpod 3.0 - using Notifier)
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  /// Attempts to login with the given [email] and [password]
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final loginUseCase = ref.read(loginUseCaseProvider);
    final result = await loginUseCase(email, password);

    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
        );
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Attempts to register a new user with [email], [password], and [name]
  Future<void> register(
    String email,
    String password,
    String name,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    final registerUseCase = ref.read(registerUseCaseProvider);
    final result = await registerUseCase(email, password, name);

    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
        );
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Logs out the current user
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);

    final logoutUseCase = ref.read(logoutUseCaseProvider);
    final result = await logoutUseCase();

    result.when(
      success: (_) {
        state = const AuthState();
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Refreshes the authentication token
  ///
  /// This is typically called automatically by the AuthInterceptor,
  /// but can be called manually if needed.
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
  Future<void> getCurrentUser() async {
    state = state.copyWith(isLoading: true, error: null);

    final getCurrentUserUseCase = ref.read(getCurrentUserUseCaseProvider);
    final result = await getCurrentUserUseCase();

    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
        );
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Checks if the user is authenticated
  ///
  /// Returns true if user is authenticated, false otherwise.
  /// This method does not update the state.
  Future<bool> isAuthenticated() async {
    final isAuthenticatedUseCase = ref.read(isAuthenticatedUseCaseProvider);
    final result = await isAuthenticatedUseCase();

    return result.when(
      success: (isAuth) => isAuth,
      failureCallback: (_) => false,
    );
  }
}

/// Provider for AuthNotifier (Riverpod 3.0 - using NotifierProvider)
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
