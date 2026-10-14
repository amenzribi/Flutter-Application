import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';

/// Creates `users/{uid}` with identity fields only when the document is absent.
///
/// Legacy signup writes `{ name, email }` with merge. This phase also uses merge
/// semantics but skips the write when the document already exists so login and
/// re-registration do not mutate existing user data.
class UserDocumentService {
  UserDocumentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> ensureIdentityDocument({
    required String uid,
    required String name,
    required String email,
  }) async {
    final ref = _users.doc(uid);
    final existing = await ref.get();
    if (existing.exists) {
      AppLogger.info('users/$uid already exists — skip identity write');
      return;
    }

    await ref.set({
      'name': name,
      'email': email.toLowerCase(),
    }, SetOptions(merge: true));
    AppLogger.info('Created users/$uid identity document');
  }

  /// Legacy `editName`: `users/{uid}.name` with merge.
  Future<void> updateName({required String uid, required String name}) =>
      _users.doc(uid).set({'name': name}, SetOptions(merge: true));

  /// Legacy `deleteAccount`: removes the private state document.
  Future<void> deleteUserDocument(String uid) => _users.doc(uid).delete();
}

AppUser mapFirebaseUser(User user) {
  return AppUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
    isPasswordUser: user.providerData.any((p) => p.providerId == 'password'),
  );
}
