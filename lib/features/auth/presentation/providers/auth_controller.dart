import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/core/utils/auth_error_mapper.dart';
import 'package:barakah40_flutter/core/utils/auth_validators.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';

enum AuthFormStatus { idle, submitting, success, error }

class AuthFormState {
  const AuthFormState({this.status = AuthFormStatus.idle, this.message});

  final AuthFormStatus status;
  final String? message;

  bool get isSubmitting => status == AuthFormStatus.submitting;

  AuthFormState copyWith({
    AuthFormStatus? status,
    String? message,
    bool clearMessage = false,
  }) {
    return AuthFormState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class AuthController extends StateNotifier<AuthFormState> {
  AuthController(this._ref) : super(const AuthFormState());

  final Ref _ref;

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final validation = AuthValidators.registerForm(
      name: name,
      email: email,
      password: password,
    );
    if (validation != null) {
      state = AuthFormState(status: AuthFormStatus.error, message: validation);
      return false;
    }

    return _run(() {
      return _ref
          .read(authRepositoryProvider)
          .registerWithEmail(name: name, email: email, password: password);
    });
  }

  Future<bool> login({required String email, required String password}) async {
    final validation = AuthValidators.loginForm(
      email: email,
      password: password,
    );
    if (validation != null) {
      state = AuthFormState(status: AuthFormStatus.error, message: validation);
      return false;
    }

    return _run(() {
      return _ref
          .read(authRepositoryProvider)
          .loginWithEmail(email: email, password: password);
    });
  }

  Future<bool> resetPassword({required String email}) async {
    final validation = AuthValidators.resetForm(email: email);
    if (validation != null) {
      state = AuthFormState(status: AuthFormStatus.error, message: validation);
      return false;
    }

    return _run(() {
      return _ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(email: email);
    }, successMessage: 'أرسلنا رابط إعادة التعيين');
  }

  Future<bool> signInWithGoogle() {
    return _run(() {
      return _ref.read(authRepositoryProvider).signInWithGoogle();
    });
  }

  Future<void> logout() async {
    state = state.copyWith(
      status: AuthFormStatus.submitting,
      clearMessage: true,
    );
    try {
      await _ref.read(authRepositoryProvider).logout();
      state = const AuthFormState(status: AuthFormStatus.success);
    } catch (error) {
      state = AuthFormState(
        status: AuthFormStatus.error,
        message: AuthErrorMapper.map(error),
      );
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true, status: AuthFormStatus.idle);
  }

  Future<bool> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    state = state.copyWith(
      status: AuthFormStatus.submitting,
      clearMessage: true,
    );
    try {
      await action();
      state = AuthFormState(
        status: AuthFormStatus.success,
        message: successMessage,
      );
      return true;
    } catch (error) {
      state = AuthFormState(
        status: AuthFormStatus.error,
        message: AuthErrorMapper.map(error),
      );
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthFormState>((ref) {
      return AuthController(ref);
    });
