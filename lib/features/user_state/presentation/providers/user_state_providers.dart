import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/features/user_state/data/repositories/firestore_user_state_repository.dart';
import 'package:barakah40_flutter/features/user_state/data/repositories/shared_preferences_user_state_repository.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/sync_status.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_local_repository.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_remote_repository.dart';
import 'package:barakah40_flutter/features/user_state/presentation/controllers/user_state_controller.dart';

/// Must be overridden in `bootstrap()` with the awaited
/// `SharedPreferences.getInstance()` singleton before `runApp`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a resolved '
    'SharedPreferences instance in bootstrap().',
  );
});

final userStateLocalRepositoryProvider = Provider<UserStateLocalRepository>((
  ref,
) {
  return SharedPreferencesUserStateRepository(
    ref.watch(sharedPreferencesProvider),
  );
});

final userStateRemoteRepositoryProvider = Provider<UserStateRemoteRepository>((
  ref,
) {
  return FirestoreUserStateRepository();
});

/// Single long-lived controller for the whole app session. It binds to
/// [authStateProvider] internally and reacts to sign-in/out/switch — it is
/// not scoped per-uid.
final userStateControllerProvider =
    StateNotifierProvider<UserStateController, UserStateSnapshot>((ref) {
      return UserStateController(
        ref,
        localRepository: ref.watch(userStateLocalRepositoryProvider),
        remoteRepository: ref.watch(userStateRemoteRepositoryProvider),
      );
    });

final userAppStateProvider = Provider<UserAppState>((ref) {
  return ref.watch(userStateControllerProvider).appState;
});

final userSyncStatusProvider = Provider<SyncStatus>((ref) {
  return ref.watch(userStateControllerProvider).syncStatus;
});

final userLastSyncedAtProvider = Provider<DateTime?>((ref) {
  return ref.watch(userStateControllerProvider).lastSyncedAt;
});
