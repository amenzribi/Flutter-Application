import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

/// On-device persistence for [UserAppState], keyed by Firebase uid.
///
/// Mirrors legacy's single global `barakah_pro_v1` key, but namespaced per
/// account so switching signed-in users on the same device never bleeds
/// state between accounts.
abstract class UserStateLocalRepository {
  /// Loads the stored state for [uid].
  ///
  /// Returns [UserAppState.defaults] when nothing is stored yet, or when the
  /// stored payload is corrupt — in the corrupt case the implementation
  /// should also overwrite the bad entry with fresh defaults so subsequent
  /// reads are clean.
  Future<UserAppState> load(String uid);

  Future<void> save(String uid, UserAppState state);

  /// Removes the stored snapshot for [uid]. Not used by normal sign-out
  /// (legacy keeps local data on logout); provided for account deletion.
  Future<void> clear(String uid);
}
