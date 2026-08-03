import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/auth/data/services/user_document_service.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    UserDocumentService? userDocumentService,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']),
       _userDocs = userDocumentService ?? UserDocumentService();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserDocumentService _userDocs;

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(
      (user) => user == null ? null : mapFirebaseUser(user),
    );
  }

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : mapFirebaseUser(user);
  }

  @override
  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedName = name.trim();
    AppLogger.info('Registering with email/password');

    final credential = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Registration succeeded without a user');
    }

    try {
      await user.updateDisplayName(trimmedName);
    } catch (error, stackTrace) {
      AppLogger.warning('updateDisplayName failed after register');
      AppLogger.error('updateDisplayName', error, stackTrace);
    }

    await _userDocs.ensureIdentityDocument(
      uid: user.uid,
      name: trimmedName,
      email: trimmedEmail,
    );

    return mapFirebaseUser(user);
  }

  @override
  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
  }) async {
    AppLogger.info('Signing in with email/password');
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Login succeeded without a user');
    }
    // Legacy syncs localStorage / cloud state later; this phase does not mutate
    // Firestore user docs on ordinary login.
    return mapFirebaseUser(user);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    AppLogger.info('Sending password reset email');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    AppLogger.info('Signing in with Google');

    late final UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(
        GoogleAuthProvider()..addScope('email'),
      );
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'popup-closed-by-user',
          message: 'Google sign-in cancelled',
        );
      }
      final googleAuth = await googleUser.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(oauthCredential);
    }

    final user = credential.user;
    if (user == null) {
      throw StateError('Google sign-in succeeded without a user');
    }

    final name = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'صديقة بركة');
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) {
      await _userDocs.ensureIdentityDocument(
        uid: user.uid,
        name: name,
        email: email,
      );
    }

    return mapFirebaseUser(user);
  }

  @override
  Future<void> logout() async {
    AppLogger.info('Signing out');
    try {
      await _googleSignIn.signOut();
    } catch (error, stackTrace) {
      AppLogger.error('Google signOut cleanup failed', error, stackTrace);
    }
    await _auth.signOut();
  }
}
