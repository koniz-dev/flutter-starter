import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';

/// Authentication state
class AuthState {
  /// Creates an [AuthState] with the given [user], [isLoading], and [error]
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  /// Currently authenticated user, null if not logged in
  final User? user;

  /// Whether an authentication operation is in progress
  final bool isLoading;

  /// Error message if authentication failed, null otherwise
  final String? error;

  /// Creates a copy of this state with updated values
  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Authentication provider (Riverpod 3.0 - using Notifier)
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  /// Attempts to login with the given [email] and [password]
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    final loginUseCase = ref.read(loginUseCaseProvider);
    final result = await loginUseCase(email, password);

    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
        );
      },
      failure: (message, code) {
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }
}

/// Provider for AuthNotifier (Riverpod 3.0 - using NotifierProvider)
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
