/// Raw payload read from / written to `users/{uid}` on Firestore.
///
/// Kept intentionally dumb (no [UserAppState] parsing) so remote
/// repositories don't need to depend on decoding logic — the controller
/// decides how to reconcile [state] with local data.
class RemoteUserState {
  const RemoteUserState({required this.state, required this.updated});

  /// Raw `users/{uid}.state` map (legacy `S` shape).
  final Map<String, dynamic> state;

  /// `users/{uid}.updated`, epoch milliseconds.
  final int updated;
}
