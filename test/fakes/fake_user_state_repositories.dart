import 'dart:async';

import 'package:barakah40_flutter/features/user_state/domain/entities/remote_user_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_local_repository.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_remote_repository.dart';

/// In-memory [UserStateLocalRepository] for unit tests — no SharedPreferences
/// plumbing required.
class FakeUserStateLocalRepository implements UserStateLocalRepository {
  final Map<String, UserAppState> _store = {};
  final List<String> loadCalls = [];
  final List<String> saveCalls = [];

  @override
  Future<UserAppState> load(String uid) async {
    loadCalls.add(uid);
    return _store[uid] ?? UserAppState.defaults();
  }

  @override
  Future<void> save(String uid, UserAppState state) async {
    saveCalls.add(uid);
    _store[uid] = state;
  }

  @override
  Future<void> clear(String uid) async {
    _store.remove(uid);
  }

  /// Test setup helper — seeds the store without going through [save].
  void seed(String uid, UserAppState state) {
    _store[uid] = state;
  }

  UserAppState? peek(String uid) => _store[uid];
}

/// In-memory [UserStateRemoteRepository] for unit tests, with a broadcast
/// stream per uid so tests can simulate `watch()` pushes independent of
/// `save()`.
class FakeUserStateRemoteRepository implements UserStateRemoteRepository {
  final Map<String, RemoteUserState?> _docs = {};
  final Map<String, StreamController<RemoteUserState?>> _controllers = {};
  final List<String> saveCalls = [];
  final Map<String, int> lastSavedUpdated = {};
  bool failFetch = false;
  bool failSave = false;

  StreamController<RemoteUserState?> _controllerFor(String uid) {
    return _controllers.putIfAbsent(
      uid,
      () => StreamController<RemoteUserState?>.broadcast(),
    );
  }

  @override
  Future<RemoteUserState?> fetch(String uid) async {
    if (failFetch) throw Exception('fetch failed');
    return _docs[uid];
  }

  @override
  Stream<RemoteUserState?> watch(String uid) => _controllerFor(uid).stream;

  @override
  Future<void> save({
    required String uid,
    required Map<String, dynamic> state,
    required int updated,
  }) async {
    saveCalls.add(uid);
    if (failSave) throw Exception('save failed');
    lastSavedUpdated[uid] = updated;
    final doc = RemoteUserState(state: state, updated: updated);
    _docs[uid] = doc;
    _controllerFor(uid).add(doc);
  }

  /// Simulates an external write (e.g. another device) arriving through the
  /// realtime listener, independent of [save].
  void pushRemoteUpdate(String uid, RemoteUserState remote) {
    _docs[uid] = remote;
    _controllerFor(uid).add(remote);
  }

  /// Test setup helper — seeds the "server" doc without notifying listeners.
  void seed(String uid, RemoteUserState? remote) {
    _docs[uid] = remote;
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
  }
}
