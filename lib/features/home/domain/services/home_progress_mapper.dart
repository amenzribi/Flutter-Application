import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/daily_prayer_schedule.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_day_progress.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/next_prayer_service.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/quran/domain/services/challenge_progress_service.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

/// Pure mapping from persisted [UserAppState] to the display-only
/// [HomeProgress] snapshot the dashboard renders.
///
/// Never invents data: a section only gets a value when the legacy field it
/// derives from is actually present/non-empty, matching
/// `HomeProgress.empty`'s "never invents fake stats" contract.
abstract final class HomeProgressMapper {
  /// [now] defaults to [DateTime.now]; tests inject a fixed instant so the
  /// next-prayer computation (which depends on wall-clock time) is
  /// deterministic.
  static HomeProgress map(UserAppState state, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final today = PrayerDayKey.dayKey(currentTime);
    final prayerToday = _prayerToday(state, today);
    final schedule = DailyPrayerSchedule.fromSettings(state.prayer, today);
    final nextInfo = schedule.hasFajr
        ? NextPrayerService.nextPrayerInfo(schedule.times, currentTime)
        : null;

    return HomeProgress(
      // No agreed-upon streak algorithm from legacy exists yet (see
      // FLUTTER_USER_STATE.md § Field status) — left null rather than
      // guessing one, per HomeProgress's "never invents fake stats" rule.
      streakDays: null,
      lastReadingLabel: _lastReadingLabel(state),
      prayerCompletedToday: prayerToday?.$1,
      prayerTotalToday: prayerToday?.$2,
      challengeDay: _challengeDay(state),
      completedChallengeDays: _completedChallengeDays(state),
      currentChallengeDay: _currentChallengeDay(state),
      treeStageLabel: _treeStageLabel(state),
      quranPercent: _quranPercent(state),
      adhkarMorningDone: _adhkarTrackedAndActive(state, 'morning'),
      adhkarEveningDone: _adhkarTrackedAndActive(state, 'evening'),
      nextPrayerName: nextInfo?.name.arabicLabel,
      nextPrayerTime: nextInfo?.time,
      nextPrayerAt: nextInfo?.at,
      lastCompletedPrayerLabel: _lastCompletedPrayerLabel(state, today),
      prayerLocationLabel: state.prayer.city.trim().isNotEmpty
          ? state.prayer.city
          : null,
    );
  }

  /// Legacy has no explicit "current day" pointer; the day the user is on is
  /// inferred as the count of completed flags (matches legacy `myDays()` /
  /// `doneCount()` used for challenge progress mirrors).
  static int? _challengeDay(UserAppState state) {
    final done = state.completed.where((day) => day).length;
    return done > 0 ? done : null;
  }

  /// Whether the challenge has any visible progress — either started (even
  /// with zero completed days yet) or has at least one completed day.
  static bool _hasChallenge(UserAppState state) =>
      state.started != null ||
      ChallengeProgressService.doneCount(state.completed) > 0;

  static int? _completedChallengeDays(UserAppState state) {
    if (!_hasChallenge(state)) return null;
    return ChallengeProgressService.doneCount(state.completed);
  }

  /// 1-based next day to complete (`currentIdx()+1`); `null` once all days
  /// are done, or when the challenge has never been started (no invented
  /// "day 1" before the user has actually engaged with it).
  static int? _currentChallengeDay(UserAppState state) {
    if (!_hasChallenge(state)) return null;
    final currentIdx = ChallengeProgressService.currentIdx(state.completed);
    return currentIdx < state.completed.length ? currentIdx + 1 : null;
  }

  static String? _lastReadingLabel(UserAppState state) {
    final ayah = state.lastAyah;
    if (ayah == null || ayah < 1) return null;
    return 'سورة البقرة — الآية $ayah من ${UserAppState.baqarahAyahCount}';
  }

  static double? _quranPercent(UserAppState state) {
    final ayah = state.lastAyah;
    if (ayah == null || ayah < 1) return null;
    final clamped = ayah.clamp(0, UserAppState.baqarahAyahCount);
    return (clamped / UserAppState.baqarahAyahCount) * 100;
  }

  static (int, int)? _prayerToday(UserAppState state, String today) {
    final record = state.prayer.recordFor(today);
    if (record.isEmpty) return null;
    final hasAnyPrayerKey = record.keys.any(
      (key) => PrayerName.fromKey(key) != null,
    );
    if (!hasAnyPrayerKey) return null;
    final progress = PrayerDayProgress.fromRecord(record);
    return (progress.completedCount, PrayerDayProgress.total);
  }

  /// Highest-order (fajr→isha) prayer marked `true` in today's log, or
  /// `null` when nothing is marked yet — legacy has no explicit "last
  /// completed" field, this is simply the last flag flipped on walking the
  /// five in order.
  static String? _lastCompletedPrayerLabel(UserAppState state, String today) {
    final record = state.prayer.recordFor(today);
    if (record.isEmpty) return null;
    String? last;
    for (final name in PrayerName.values) {
      if (record[name.key] == true) last = name.arabicLabel;
    }
    return last;
  }

  /// `true` once any counter for [mode] (`'morning'`/`'evening'`) has
  /// progress; `null` when that mode has never been touched. There is no
  /// on-device catalog of adhkar targets to judge "fully done", so this
  /// intentionally reports presence rather than completion — see
  /// FLUTTER_USER_STATE.md § Decisions.
  static bool? _adhkarTrackedAndActive(UserAppState state, String mode) {
    final prefix = '${mode}_';
    final entries = state.adhkarCount.entries.where(
      (entry) => entry.key.startsWith(prefix),
    );
    if (entries.isEmpty) return null;
    return entries.any((entry) {
      final value = entry.value;
      return value is num && value > 0;
    });
  }

  static String? _treeStageLabel(UserAppState state) {
    final tree = state.extraMap('tree');
    if (tree == null) return null;
    final stage = tree['shownStage'];
    if (stage is! num) return null;
    return 'مرحلة الشجرة ${stage.toInt() + 1} من 20';
  }
}
