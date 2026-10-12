/// Authenticated user identity exposed to presentation.
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.isPasswordUser = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;

  /// Signed up with email and password (not only Google).
  final bool isPasswordUser;

  /// Legacy rule: a password account syncs progress to the cloud only after
  /// its email is confirmed; until then progress stays on this device.
  bool get needsEmailVerification => isPasswordUser && !emailVerified;
}
