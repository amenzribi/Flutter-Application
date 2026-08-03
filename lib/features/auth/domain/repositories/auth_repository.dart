import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';

/// Authentication contract — implemented by Firebase-backed repository.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<AppUser> signInWithGoogle();

  Future<void> logout();
}
