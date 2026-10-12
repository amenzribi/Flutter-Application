import 'dart:async';

import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser}) : _user = initialUser {
    _controller = StreamController<AppUser?>.broadcast();
  }

  AppUser? _user;
  late final StreamController<AppUser?> _controller;
  bool failNext = false;
  Object? nextError;
  int logoutCalls = 0;
  int registerCalls = 0;
  int loginCalls = 0;
  int resetCalls = 0;
  int googleCalls = 0;

  void emit(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _user;

  Future<T> _guard<T>(Future<T> Function() action) async {
    if (failNext) {
      failNext = false;
      throw nextError ?? FirebaseAuthException(code: 'network-request-failed');
    }
    return action();
  }

  @override
  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard(() async {
      registerCalls++;
      final user = AppUser(
        uid: 'uid-register',
        email: email.trim().toLowerCase(),
        displayName: name.trim(),
      );
      emit(user);
      return user;
    });
  }

  @override
  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      loginCalls++;
      final user = AppUser(uid: 'uid-login', email: email.trim());
      emit(user);
      return user;
    });
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _guard(() async {
      resetCalls++;
    });
  }

  int verificationCalls = 0;

  @override
  Future<void> sendEmailVerification() =>
      _guard(() async => verificationCalls++);

  @override
  Future<AppUser?> reloadUser() async => _user;

  @override
  Future<void> updateDisplayName(String name) => _guard(() async {
    final u = _user;
    if (u != null) {
      emit(AppUser(uid: u.uid, email: u.email, displayName: name.trim()));
    }
  });

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _guard(() async {});

  @override
  Future<void> reauthenticate({String? password}) => _guard(() async {});

  int deleteCalls = 0;

  @override
  Future<void> deleteAccount() => _guard(() async {
    deleteCalls++;
    emit(null);
  });

  @override
  Future<AppUser> signInWithGoogle() {
    return _guard(() async {
      googleCalls++;
      const user = AppUser(
        uid: 'uid-google',
        email: 'google@example.com',
        displayName: 'Google User',
      );
      emit(user);
      return user;
    });
  }

  @override
  Future<void> logout() {
    return _guard(() async {
      logoutCalls++;
      emit(null);
    });
  }

  void dispose() {
    _controller.close();
  }
}
