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

  /// Sends the "confirm your email" link to the signed-in password user.
  Future<void> sendEmailVerification();

  /// Re-reads the signed-in user (e.g. after confirming the email elsewhere).
  Future<AppUser?> reloadUser();

  /// Legacy "تعديل الاسم": Auth display name plus `users/{uid}.name`.
  Future<void> updateDisplayName(String name);

  /// Password accounts: re-checks [currentPassword], then sets [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Confirms it is really the owner: the password for password accounts,
  /// a Google pop-up otherwise. Required right before deleting the account.
  Future<void> reauthenticate({String? password});

  /// Deletes `users/{uid}` and the Auth account. Call [reauthenticate] first.
  Future<void> deleteAccount();

  Future<void> logout();
}
