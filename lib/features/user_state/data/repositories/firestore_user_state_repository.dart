import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:barakah40_flutter/features/user_state/domain/entities/remote_user_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_remote_repository.dart';

/// Firestore-backed remote repository for `users/{uid}`.
///
/// Only ever reads/writes the `state` and `updated` fields, always with
/// `SetOptions(merge: true)`, so sibling identity fields written elsewhere
/// (`name`, `email`, `photo`, `fcmToken`, `tz`, …) are never clobbered.
class FirestoreUserStateRepository implements UserStateRemoteRepository {
  FirestoreUserStateRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<RemoteUserState?> fetch(String uid) async {
    final snapshot = await _doc(uid).get();
    return _fromSnapshot(snapshot);
  }

  @override
  Stream<RemoteUserState?> watch(String uid) {
    return _doc(uid).snapshots().map(_fromSnapshot);
  }

  @override
  Future<void> save({
    required String uid,
    required Map<String, dynamic> state,
    required int updated,
  }) {
    return _doc(
      uid,
    ).set({'state': state, 'updated': updated}, SetOptions(merge: true));
  }

  RemoteUserState? _fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    final stateRaw = data['state'];
    if (stateRaw is! Map) return null;
    final updatedRaw = data['updated'];
    final updated = updatedRaw is num ? updatedRaw.toInt() : 0;
    return RemoteUserState(
      state: Map<String, dynamic>.from(stateRaw),
      updated: updated,
    );
  }
}
