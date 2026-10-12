import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_tracking_service.dart';
import 'package:barakah40_flutter/features/quran/domain/services/challenge_progress_service.dart';
import 'package:barakah40_flutter/features/tree/domain/tree_growth_service.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/qibla_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/reminder_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/remote_user_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/sync_status.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/tasbeeh_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_local_repository.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_remote_repository.dart';

/// Optional override for the legacy `isPwUser && !emailVerified` cloud-write
/// gate. Tests inject this; production leaves it null and uses Firebase Auth.
typedef UserStateCloudWriteGate = bool Function(AppUser user);

/// Debounce window before a local change is pushed to Firestore.
/// Matches legacy `Cloud.scheduleSave` (`setTimeout(..., 1200)`).
const kUserStateSyncDebounce = Duration(milliseconds: 1200);

/// Echo-suppression window for the remote listener. Matches legacy
/// `Math.abs(data.updated - Cloud.lastPush) < 3000`.
const kUserStateEchoWindow = Duration(milliseconds: 3000);

/// Bundled read-model exposed to the UI: current app state + sync
/// bookkeeping, so widgets can watch one provider for everything they need.
class UserStateSnapshot {
  const UserStateSnapshot({
    required this.appState,
    this.syncStatus = SyncStatus.initial,
    this.lastSyncedAt,
    this.uid,
  });

  factory UserStateSnapshot.initial() =>
      UserStateSnapshot(appState: UserAppState.defaults());

  final UserAppState appState;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;

  /// uid of the signed-in user this snapshot belongs to, or `null` when
  /// signed out. Kept here (not derived from [authStateProvider] directly)
  /// so the diagnostics panel and home mapper only need one provider.
  final String? uid;

  UserStateSnapshot copyWith({
    UserAppState? appState,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? uid,
    bool clearUid = false,
  }) {
    return UserStateSnapshot(
      appState: appState ?? this.appState,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
      uid: clearUid ? null : (uid ?? this.uid),
    );
  }
}

/// Owns the single source of truth for the signed-in user's [UserAppState]
/// and its synchronization with Firestore.
///
/// See `docs/migration-analysis/FLUTTER_USER_STATE.md` § Sync strategy for
/// the full write-up. Summary of behavior:
///
/// - Binds to [authStateProvider]; every uid transition reloads local then
///   remote state for that uid.
/// - First-load reconciliation mirrors legacy `Cloud.pull()` in
///   login/bootstrap: if a remote document already exists, remote wins and
///   is written back to local storage; otherwise the local snapshot is
///   pushed as the account's first cloud write.
/// - Local edits go through [applyPatch] (or a focused `updateX` helper),
///   which writes to SharedPreferences immediately and schedules a
///   debounced ([kUserStateSyncDebounce]) Firestore write.
/// - The realtime remote listener ignores updates that land within
///   [kUserStateEchoWindow] of our own last push, to avoid reprocessing our
///   own write as if it were a remote change (legacy `Cloud.listen` echo
///   guard).
/// - Sign-out clears in-memory state only. Legacy never deletes
///   `barakah_pro_v1` on logout (only `profile_photo`), so the
///   SharedPreferences entry for the uid is left untouched — signing back
///   in reloads it.
/// - There is deliberately no public setter that replaces the whole state
///   from the UI; call a focused method or [applyPatch].
class UserStateController extends StateNotifier<UserStateSnapshot> {
  UserStateController(
    this._ref, {
    required UserStateLocalRepository localRepository,
    required UserStateRemoteRepository remoteRepository,
    this.cloudWriteAllowed,
  }) : // Fields are private but parameters are named for call-site
       // readability (`localRepository: ...`), so an initializing formal
       // (which would require a matching, non-private parameter name)
       // isn't used here.
       // ignore: prefer_initializing_formals
       _localRepository = localRepository,
       // ignore: prefer_initializing_formals
       _remoteRepository = remoteRepository,
       super(UserStateSnapshot.initial()) {
    _authSubscription = _ref.listen<AsyncValue<AppUser?>>(authStateProvider, (
      previous,
      next,
    ) {
      next.whenData(_handleAuthUser);
    }, fireImmediately: true);
  }

  final Ref _ref;
  final UserStateLocalRepository _localRepository;
  final UserStateRemoteRepository _remoteRepository;

  /// When non-null, replaces the production Firebase Auth provider check.
  final UserStateCloudWriteGate? cloudWriteAllowed;

  ProviderSubscription<AsyncValue<AppUser?>>? _authSubscription;
  StreamSubscription<RemoteUserState?>? _remoteSubscription;
  Timer? _debounceTimer;

  /// Epoch ms of our most recent successful remote write, used to detect
  /// and ignore the echo of that same write coming back through [_remoteSubscription].
  int _lastPush = 0;

  /// Bumped on every auth transition so a slow load that resolves after a
  /// newer transition started can detect it's stale and no-op.
  int _loadGeneration = 0;

  /// A write was skipped because the password account's email is not yet
  /// confirmed; retried once it is.
  bool _heldForVerification = false;

  /// `null` once [dispose] has been called, so pending async work resuming
  /// after teardown (e.g. in tests) can no-op instead of throwing when it
  /// tries to touch `state`.
  String? get currentUid => mounted ? state.uid : null;

  /// Public read of the current snapshot, for consumers outside this
  /// notifier's own subclass hierarchy (e.g. [HomeRepositoryImpl]) that
  /// can't touch the protected `state` getter directly.
  UserStateSnapshot get snapshot => state;

  Future<void> _handleAuthUser(AppUser? user) async {
    if (user != null && user.uid == state.uid) {
      // Same signed-in user re-emitted (e.g. Firebase token refresh) — the
      // session hasn't actually changed, nothing to reload. The one change
      // that matters: the email was just confirmed, so the progress held
      // back on this device can now go to the cloud.
      if (_heldForVerification && _allowsCloudWrite(user)) {
        _heldForVerification = false;
        await _pushNow(user: user, appState: state.appState);
      }
      return;
    }

    final generation = ++_loadGeneration;
    _heldForVerification = false;
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (!mounted) return;

    if (user == null) {
      state = UserStateSnapshot.initial();
      return;
    }

    state = UserStateSnapshot(
      appState: UserAppState.defaults(),
      syncStatus: SyncStatus.loadingLocal,
      uid: user.uid,
    );

    final local = await _localRepository.load(user.uid);
    if (!mounted || generation != _loadGeneration) return;
    state = state.copyWith(
      appState: local,
      syncStatus: SyncStatus.loadingRemote,
    );

    try {
      final remote = await _remoteRepository.fetch(user.uid);
      if (!mounted || generation != _loadGeneration) return;

      if (remote != null) {
        final merged = UserAppState.fromJson(remote.state);
        state = state.copyWith(
          appState: merged,
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(remote.updated),
        );
        await _localRepository.save(user.uid, merged);
      } else {
        await _pushNow(user: user, appState: local);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Initial user-state reconciliation failed for uid=${user.uid}',
        error,
        stackTrace,
      );
      if (mounted && generation == _loadGeneration) {
        state = state.copyWith(syncStatus: SyncStatus.offline);
      }
    }

    if (!mounted || generation != _loadGeneration) return;
    _remoteSubscription = _remoteRepository
        .watch(user.uid)
        .listen(
          (remote) => _handleRemoteUpdate(user.uid, remote),
          onError: (Object error, StackTrace stackTrace) {
            AppLogger.error('User-state listener error', error, stackTrace);
            if (mounted && currentUid == user.uid) {
              state = state.copyWith(syncStatus: SyncStatus.offline);
            }
          },
        );
  }

  void _handleRemoteUpdate(String uid, RemoteUserState? remote) {
    if (!mounted || remote == null || currentUid != uid) return;
    if ((remote.updated - _lastPush).abs() <
        kUserStateEchoWindow.inMilliseconds) {
      // This is (almost certainly) the snapshot our own recent write
      // produced — ignore it, matching legacy's `Cloud.listen` guard.
      return;
    }
    final merged = UserAppState.fromJson(remote.state);
    state = state.copyWith(
      appState: merged,
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(remote.updated),
    );
    unawaited(_localRepository.save(uid, merged));
  }

  Future<void> _pushNow({
    required AppUser user,
    required UserAppState appState,
  }) async {
    if (!mounted) return;
    if (!_allowsCloudWrite(user)) {
      // Legacy: skip only when `isPwUser(u) && emailVerified===false`.
      _heldForVerification = true;
      state = state.copyWith(syncStatus: SyncStatus.offline);
      return;
    }

    final updated = DateTime.now().millisecondsSinceEpoch;
    _lastPush = updated;
    try {
      await _remoteRepository.save(
        uid: user.uid,
        state: appState.toJson(),
        updated: updated,
      );
      if (currentUid == user.uid) {
        state = state.copyWith(
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(updated),
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Push user state failed for uid=${user.uid}',
        error,
        stackTrace,
      );
      if (currentUid == user.uid) {
        state = state.copyWith(syncStatus: SyncStatus.error);
      }
    }
  }

  /// Whether a cloud write is allowed for this auth user (legacy scheduleSave).
  bool _allowsCloudWrite(AppUser user) {
    if (cloudWriteAllowed != null) {
      return cloudWriteAllowed!(user);
    }
    if (user.emailVerified) return true;
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null || firebaseUser.uid != user.uid) {
        // Tests / unavailable Auth: treat unverified as password-gated.
        return false;
      }
      final isPassword = firebaseUser.providerData.any(
        (provider) => provider.providerId == 'password',
      );
      return !isPassword;
    } catch (_) {
      return false;
    }
  }

  /// Single internal entry point for state mutations. Immediately updates
  /// in-memory state and SharedPreferences, then schedules a debounced
  /// Firestore write. UI code should prefer the focused `updateX` helpers
  /// below; use this directly only for a genuinely new focused mutation
  /// that doesn't warrant its own named method yet.
  void applyPatch(UserAppState Function(UserAppState current) patch) {
    final uid = currentUid;
    if (uid == null) return;

    final next = patch(state.appState);
    state = state.copyWith(appState: next, syncStatus: SyncStatus.syncing);
    unawaited(_localRepository.save(uid, next));
    _scheduleRemoteSave(uid, next);
  }

  void _scheduleRemoteSave(String uid, UserAppState appState) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(kUserStateSyncDebounce, () {
      if (currentUid != uid) return;
      final user = _ref.read(currentUserProvider);
      if (user == null || user.uid != uid) return;
      unawaited(_pushNow(user: user, appState: appState));
    });
  }

  // ---- Focused public mutators --------------------------------------
  //
  // Deliberately no `replaceState(UserAppState)` — every mutation goes
  // through a named, intention-revealing method (or `applyPatch` for a new
  // one-off) so callers can't accidentally drop fields they don't know
  // about.

  void updateLang(String lang) => applyPatch((s) => s.copyWith(lang: lang));

  /// Debug-only convenience used by [UserStateDiagnosticsPanel] to exercise
  /// the sync pipeline with a known-safe field.
  void toggleLangDebugProbe() =>
      updateLang(state.appState.lang == 'ar' ? 'en' : 'ar');

  void setLastAyah(int? ayah) => applyPatch(
    (s) => s.copyWith(lastAyah: ayah, clearLastAyah: ayah == null),
  );

  void setAudioPos(int? position) => applyPatch(
    (s) => s.copyWith(audioPos: position, clearAudioPos: position == null),
  );

  void setCompleted(List<bool> completed) =>
      applyPatch((s) => s.copyWith(completed: completed));

  void setDayCompleted(int index, bool value) => applyPatch((s) {
    final next = List<bool>.from(s.completed);
    if (index >= 0 && index < next.length) next[index] = value;
    return s.copyWith(completed: next);
  });

  /// Marks challenge day [index] complete (legacy `toggleDay`/`#markDayBtn`
  /// confirm sheet). A no-op — no state change, no sync churn — when that
  /// day is already complete, per Option A's "manual, duplicate-safe"
  /// completion rule.
  void completeChallengeDay(int index) {
    if (!ChallengeProgressService.canComplete(
      state.appState.completed,
      index,
    )) {
      return;
    }
    applyPatch((s) {
      final result = ChallengeProgressService.completeDay(s, index);
      final next = s.copyWith(
        completed: result.completed,
        started: result.started,
        extra: {...s.extra, 'completedAt': result.completedAt},
      );
      // Legacy: completing a day calls markActivity('read').
      return TreeGrowthService.recordActivity(
        next,
        TreeActivity.read,
        DateTime.now(),
      );
    });
  }

  /// Undoes challenge day [index] (legacy: tap a done day, or `#undoBtn`
  /// for the last done day). A no-op when that day isn't currently done.
  void uncompleteChallengeDay(int index) {
    if (!ChallengeProgressService.canUncomplete(
      state.appState.completed,
      index,
    )) {
      return;
    }
    applyPatch((s) {
      final result = ChallengeProgressService.uncompleteDay(s, index);
      return s.copyWith(
        completed: result.completed,
        extra: {...s.extra, 'completedAt': result.completedAt},
      );
    });
  }

  /// Sets `S.started` to now, only if it isn't already set (legacy: several
  /// entry points do `if(!S.started)S.started=Date.now()`, e.g. guest
  /// sign-in) — idempotent, never overwrites an existing start time.
  void ensureStarted() {
    if (state.appState.started != null) return;
    applyPatch(
      (s) => s.copyWith(started: DateTime.now().millisecondsSinceEpoch),
    );
  }

  /// Sets the EveryAyah reciter id (`S.reciter`).
  void setReciter(String reciterId) =>
      applyPatch((s) => s.copyWith(reciter: reciterId));

  /// Sets the Quran reader font scale (`S.qscale`, legacy range 0.8..1.8).
  void setQscale(double qscale) =>
      applyPatch((s) => s.copyWith(qscale: qscale));

  /// Toggles the single reading bookmark (legacy "وصلت هنا" / "آخر موضع"):
  /// tapping the already-bookmarked ayah clears it; tapping any other ayah
  /// moves the bookmark there. There is no bookmark list — Option A keeps
  /// exactly one, backed by `S.lastAyah`.
  void toggleLastAyahBookmark(int ayah) => applyPatch((s) {
    final next = s.lastAyah == ayah ? null : ayah;
    final updated = s.copyWith(lastAyah: next, clearLastAyah: next == null);
    // Legacy `setBookmark`: setting (not clearing) a bookmark marks reading.
    return next == null
        ? updated
        : TreeGrowthService.recordActivity(
            updated,
            TreeActivity.read,
            DateTime.now(),
          );
  });

  void updateReminder(
    ReminderSettings Function(ReminderSettings current) update,
  ) => applyPatch((s) => s.copyWith(reminder: update(s.reminder)));

  void updatePrayer(PrayerSettings Function(PrayerSettings current) update) =>
      applyPatch((s) => s.copyWith(prayer: update(s.prayer)));

  /// Toggles today's completion flag for a prayer (legacy `markPrayer`):
  /// mark on, or undo — **no confirm dialog**, unlike the challenge-day
  /// mutators. Accepts either a [PrayerName] or its raw legacy key string;
  /// a no-op (no state change, no sync churn) for an unrecognized key.
  void togglePrayerCompleted(Object nameOrKey) {
    final key = nameOrKey is PrayerName ? nameOrKey.key : nameOrKey.toString();
    final today = PrayerDayKey.dayKey();
    final currentLog = state.appState.prayer.log;
    final nextLog = PrayerTrackingService.togglePrayer(currentLog, today, key);
    if (identical(nextLog, currentLog)) return;
    final nowDone = (nextLog[today] as Map?)?[key] == true;
    applyPatch((s) {
      final updated = s.copyWith(prayer: s.prayer.copyWith(log: nextLog));
      // Legacy `markPrayer`: marking (not undoing) calls markActivity.
      return nowDone
          ? TreeGrowthService.recordActivity(
              updated,
              TreeActivity.prayer,
              DateTime.now(),
            )
          : updated;
    });
  }

  /// Saves a manually-entered prayer city/country and clears `timesDate` to
  /// force a refetch on next schedule read (legacy `openCity`'s save
  /// handler: `S.prayer.timesDate=''`).
  void setPrayerCity({required String city, required String country}) {
    applyPatch(
      (s) => s.copyWith(
        prayer: s.prayer.copyWith(city: city, country: country, timesDate: ''),
      ),
    );
  }

  /// Persists a freshly-fetched prayer schedule. [lat]/[lng]/[tz] are only
  /// ever passed on the GPS path and are stored in [PrayerSettings.extra]
  /// so they sync alongside the rest of `S.prayer`, matching legacy's flat
  /// `S.prayer.lat`/`lng`/`tz` fields (`PrayerSettings.toJson` spreads
  /// `extra` at the top level). [city]/[country] are only overwritten when
  /// provided (the manual-city fetch path leaves them untouched).
  void applyPrayerSchedule({
    required Map<PrayerName, String> times,
    required String timesDate,
    String? city,
    String? country,
    double? lat,
    double? lng,
    String? tz,
  }) {
    final timesJson = <String, dynamic>{
      for (final entry in times.entries) entry.key.key: entry.value,
    };
    applyPatch((s) {
      final extra = Map<String, dynamic>.from(s.prayer.extra);
      if (lat != null) extra['lat'] = lat;
      if (lng != null) extra['lng'] = lng;
      if (tz != null) extra['tz'] = tz;
      return s.copyWith(
        prayer: s.prayer.copyWith(
          times: timesJson,
          timesDate: timesDate,
          city: city ?? s.prayer.city,
          country: country ?? s.prayer.country,
          extra: extra,
        ),
      );
    });
  }

  void updateQibla(QiblaSettings Function(QiblaSettings current) update) =>
      applyPatch((s) => s.copyWith(qibla: update(s.qibla)));

  void updateTasbeeh(
    TasbeehSettings Function(TasbeehSettings current) update,
  ) => applyPatch((s) => s.copyWith(tasbeeh: update(s.tasbeeh)));

  void incrementAdhkar(String key, {int max = 999999}) => applyPatch((s) {
    final next = Map<String, dynamic>.from(s.adhkarCount);
    final current = next[key] is num ? (next[key] as num).toInt() : 0;
    next[key] = (current + 1).clamp(0, max);
    return TreeGrowthService.recordActivity(
      s.copyWith(adhkarCount: next),
      TreeActivity.adhkar,
      DateTime.now(),
    );
  });

  /// Legacy "إعادة التحدّي" (`openRestart`): clears all progress, points,
  /// tree and achievements, and keeps the settings (theme, Quran font size,
  /// reciter, reminders, name, prayer city without its log, qibla, language).
  void restartChallenge() => applyPatch((s) {
    final now = DateTime.now();
    final extra = Map<String, dynamic>.from(s.extra)
      ..remove('stats')
      ..remove('activity')
      ..remove('season')
      ..['completedAt'] = <String, dynamic>{}
      ..['tree'] = {
        'shownStage': 0,
        'stageDay': PrayerDayKey.dayKey(now),
        'grownToday': 0,
        'vitality': 1,
        'lastActive': now.millisecondsSinceEpoch,
        'createdAt': now.millisecondsSinceEpoch,
      };
    return UserAppState.defaults().copyWith(
      palette: s.palette,
      qscale: s.qscale,
      reciter: s.reciter,
      reminder: s.reminder,
      prayer: s.prayer.copyWith(log: const {}, times: const {}, timesDate: ''),
      qibla: s.qibla,
      lang: s.lang,
      guest: s.guest,
      seen: true,
      started: now.millisecondsSinceEpoch,
      extra: extra,
    );
  });

  /// Legacy `todayKey()` used by the intention map: `2026-10-12` style but
  /// without zero padding (`2026-1-5`).
  static String intentionKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Legacy "نيّتي اليوم": `S.intention[todayKey()] = text`.
  void setIntentionToday(String text) => applyPatch((s) {
    final next = Map<String, dynamic>.from(s.intention);
    next[intentionKey(DateTime.now())] = text.trim();
    return s.copyWith(intention: next);
  });

  /// Legacy "دفتر المشاعر": appends `{date: '١٢/١٠/٢٠٢٦', text}`.
  void addJournalEntry(String text, String dateLabel) {
    final body = text.trim();
    if (body.isEmpty) return;
    applyPatch(
      (s) => s.copyWith(
        journal: [
          ...s.journal,
          {'date': dateLabel, 'text': body},
        ],
      ),
    );
  }

  /// Legacy adhkar "−" button: one down, never below 0, no activity.
  void decrementAdhkar(String key) {
    final v = state.appState.adhkarCount[key];
    final current = v is num ? v.toInt() : 0;
    if (current <= 0) return;
    applyPatch((s) {
      final next = Map<String, dynamic>.from(s.adhkarCount);
      next[key] = current - 1;
      return s.copyWith(adhkarCount: next);
    });
  }

  /// Legacy `tbTap`: one more tasbih, recorded as today's activity.
  void tapTasbeeh() => applyPatch(
    (s) => TreeGrowthService.recordActivity(
      s.copyWith(tasbeeh: s.tasbeeh.copyWith(count: s.tasbeeh.count + 1)),
      TreeActivity.tasbih,
      DateTime.now(),
    ),
  );

  /// Legacy tasbih target buttons (0 = open count).
  void setTasbeehTarget(int target) =>
      updateTasbeeh((t) => t.copyWith(target: target));

  /// Legacy "تصفير العدّاد".
  void resetTasbeeh() => updateTasbeeh((t) => t.copyWith(count: 0));

  /// Sets or removes a single runtime/partial [UserAppState.extra] field
  /// (e.g. `tree`) without disturbing confirmed fields or other extras.
  void updateExtra(String key, Object? value) =>
      applyPatch((s) => s.copyWithExtra(key, value));

  @override
  void dispose() {
    _authSubscription?.close();
    _remoteSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
