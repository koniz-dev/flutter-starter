import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../../../core/utils/result.dart';

/// Authentication state
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

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

/// Provider for LoginUseCase (to be provided via dependency injection)
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  // This should be provided via dependency injection
  // For now, throw an error to indicate it needs to be set up
  throw UnimplementedError('LoginUseCase must be provided');
});

/// Authentication provider (Riverpod 3.0 - using Notifier)
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

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

