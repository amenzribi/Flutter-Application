import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/home/data/repositories/home_repository_impl.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/remote_user_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/sync_status.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

/// Flushes pending microtasks (local/remote fake repositories resolve
/// immediately, but still go through real `Future`/`Stream` plumbing).
Future<void> settle([int ticks = 8]) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeAuthRepository auth;
  late FakeUserStateLocalRepository local;
  late FakeUserStateRemoteRepository remote;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    local = FakeUserStateLocalRepository();
    remote = FakeUserStateRemoteRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userStateLocalRepositoryProvider.overrideWithValue(local),
        userStateRemoteRepositoryProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(() {
      auth.dispose();
      remote.dispose();
      container.dispose();
    });
  });

  test('initial state before any sign-in', () {
    container.read(userStateControllerProvider.notifier); // instantiate
    final snapshot = container.read(userStateControllerProvider);
    expect(snapshot.syncStatus, SyncStatus.initial);
    expect(snapshot.uid, isNull);
    expect(snapshot.appState.completed, List<bool>.filled(40, false));
  });

  test(
    'first login with no remote doc pushes local as the initial cloud write',
    () async {
      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();

      final snapshot = container.read(userStateControllerProvider);
      expect(snapshot.uid, 'u1');
      expect(snapshot.syncStatus, SyncStatus.synced);
      expect(remote.saveCalls, ['u1']);
      expect(local.loadCalls, contains('u1'));
    },
  );

  test(
    'remote state wins over local on first load when a doc already exists',
    () async {
      local.seed('u1', UserAppState.defaults().copyWith(lang: 'ar'));
      remote.seed(
        'u1',
        RemoteUserState(
          state: {'lang': 'en', 'completed': List<bool>.filled(40, false)},
          updated: 1000,
        ),
      );

      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();

      final snapshot = container.read(userStateControllerProvider);
      expect(snapshot.appState.lang, 'en');
      expect(snapshot.syncStatus, SyncStatus.synced);
      expect(
        remote.saveCalls,
        isEmpty,
      ); // did not push — remote already had a doc
      expect(local.peek('u1')?.lang, 'en'); // remote reconciled back to local
    },
  );

  test(
    'unverified user does not push and reports offline (legacy isPwUser guard)',
    () async {
      container.read(userStateControllerProvider.notifier);
      auth.emit(
        const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: false),
      );
      await settle();

      expect(remote.saveCalls, isEmpty);
      expect(
        container.read(userStateControllerProvider).syncStatus,
        SyncStatus.offline,
      );
    },
  );

  test(
    'applyPatch (via updateLang) updates state immediately and debounces the remote save',
    () async {
      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();
      remote.saveCalls.clear();

      final notifier = container.read(userStateControllerProvider.notifier);
      notifier.updateLang('en');

      expect(container.read(userStateControllerProvider).appState.lang, 'en');
      expect(
        container.read(userStateControllerProvider).syncStatus,
        SyncStatus.syncing,
      );
      expect(remote.saveCalls, isEmpty); // not yet pushed — debounce pending
      expect(
        local.peek('u1')?.lang,
        'en',
      ); // local save is immediate, not debounced

      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect(remote.saveCalls, ['u1']);
      expect(
        container.read(userStateControllerProvider).syncStatus,
        SyncStatus.synced,
      );
    },
  );

  test(
    'rapid successive patches coalesce into a single debounced remote save',
    () async {
      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();
      remote.saveCalls.clear();

      final notifier = container.read(userStateControllerProvider.notifier);
      notifier.updateLang('en');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      notifier.updateLang('ar');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      notifier.updateLang('en');

      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect(remote.saveCalls, ['u1']); // single flush, not three
      expect(container.read(userStateControllerProvider).appState.lang, 'en');
    },
  );

  test(
    'remote echo within the 3s window is ignored; a later external write is applied',
    () async {
      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();
      remote.saveCalls.clear();

      final notifier = container.read(userStateControllerProvider.notifier);
      notifier.updateLang('en');
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect(remote.saveCalls, ['u1']);
      final lastPush = remote.lastSavedUpdated['u1']!;

      // Simulated echo of our own write (close timestamp) — must be ignored.
      remote.pushRemoteUpdate(
        'u1',
        RemoteUserState(
          state: {'lang': 'ar', 'completed': List<bool>.filled(40, false)},
          updated: lastPush + 500,
        ),
      );
      await settle();
      expect(container.read(userStateControllerProvider).appState.lang, 'en');

      // A genuinely later external write (outside the echo window) is applied.
      remote.pushRemoteUpdate(
        'u1',
        RemoteUserState(
          state: {'lang': 'ar', 'completed': List<bool>.filled(40, false)},
          updated: lastPush + 5000,
        ),
      );
      await settle();
      expect(container.read(userStateControllerProvider).appState.lang, 'ar');
    },
  );

  test(
    'logout clears in-memory state but keeps the local snapshot on disk',
    () async {
      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();

      container.read(userStateControllerProvider.notifier).updateLang('en');
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      auth.emit(null);
      await settle();

      final snapshot = container.read(userStateControllerProvider);
      expect(snapshot.uid, isNull);
      expect(snapshot.appState.lang, 'ar'); // reset to defaults in-memory
      expect(local.peek('u1')?.lang, 'en'); // persisted copy left untouched
    },
  );

  test(
    'switching accounts loads the other uid\'s local+remote state',
    () async {
      local.seed('u1', UserAppState.defaults().copyWith(lang: 'en'));
      local.seed('u2', UserAppState.defaults().copyWith(lang: 'ar'));

      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();
      expect(container.read(userStateControllerProvider).appState.lang, 'en');

      auth.emit(const AppUser(uid: 'u2', email: 'c@d.co', emailVerified: true));
      await settle();
      final snapshot = container.read(userStateControllerProvider);
      expect(snapshot.uid, 'u2');
      expect(snapshot.appState.lang, 'ar');
    },
  );

  test(
    're-emitting the same signed-in user (token refresh) does not reload',
    () async {
      local.seed('u1', UserAppState.defaults().copyWith(lang: 'en'));
      container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();
      local.loadCalls.clear();

      auth.emit(
        const AppUser(
          uid: 'u1',
          email: 'a@b.co',
          emailVerified: true,
          displayName: 'unrelated refresh',
        ),
      );
      await settle();

      expect(local.loadCalls, isEmpty); // no reload triggered
    },
  );

  test('HomeRepositoryImpl reflects controller updates end-to-end', () async {
    final notifier = container.read(userStateControllerProvider.notifier);
    final repository = HomeRepositoryImpl(notifier);

    expect(repository.getProgress().hasChallenge, isFalse);

    auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
    await settle();

    final updates = repository.watchProgress();
    final future = updates.firstWhere((p) => p.hasChallenge);

    notifier.setDayCompleted(0, true);
    notifier.setDayCompleted(1, true);

    final progress = await future;
    expect(progress.challengeDay, 2);
  });
}
