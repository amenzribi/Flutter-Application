import 'package:barakah40_flutter/features/user_state/domain/entities/remote_user_state.dart';

/// Cloud persistence contract for `users/{uid}` `state` + `updated`.
///
/// Implementations must merge-write only these two fields and must never
/// overwrite sibling document fields such as `name`, `email`, `photo`,
/// `fcmToken`, or `tz` — those are owned by other features.
abstract class UserStateRemoteRepository {
  /// One-shot read, used for first-load reconciliation.
  Future<RemoteUserState?> fetch(String uid);

  /// Realtime updates, used for cross-device sync after the first load.
  Stream<RemoteUserState?> watch(String uid);

  /// Merge-writes `{state, updated}` onto `users/{uid}`.
  Future<void> save({
    required String uid,
    required Map<String, dynamic> state,
    required int updated,
  });
}
