/// Snapshot of home dashboard progress. Null/empty fields mean no data yet.
class HomeProgress {
  const HomeProgress({
    this.streakDays,
    this.lastReadingLabel,
    this.prayerCompletedToday,
    this.prayerTotalToday,
    this.challengeDay,
    this.challengeGoalDays = 40,
    this.completedChallengeDays,
    this.currentChallengeDay,
    this.treeStageLabel,
    this.quranPercent,
    this.adhkarMorningDone,
    this.adhkarEveningDone,
    this.nextPrayerName,
    this.nextPrayerTime,
    this.nextPrayerAt,
    this.lastCompletedPrayerLabel,
    this.prayerLocationLabel,
  });

  /// Consecutive active days. Null = never started.
  final int? streakDays;

  /// Human label for last Quran position, e.g. "البقرة ٢:١٥". Null = none.
  final String? lastReadingLabel;

  final int? prayerCompletedToday;
  final int? prayerTotalToday;

  /// Challenge day index 1..40. Null = challenge not started.
  ///
  /// Historically the count of completed days (see [completedChallengeDays]
  /// for the same value under an unambiguous name). Kept for existing
  /// callers; prefer [completedChallengeDays]/[currentChallengeDay] in new
  /// code, which distinguish "days done" from "next day to do".
  final int? challengeDay;
  final int challengeGoalDays;

  /// Number of challenge days marked complete (`doneCount()`). Null when
  /// the challenge has neither been started nor has any completed day.
  final int? completedChallengeDays;

  /// 1-based number of the next day to complete (legacy `currentIdx()+1`).
  /// Null once all 40 days are done.
  final int? currentChallengeDay;

  /// Living tree stage label. Null = garden not started.
  final String? treeStageLabel;

  /// 0..100 Al-Baqarah reading completion from the current position
  /// (`lastAyah`/`audioPos`), separate from day-completion percent. Null =
  /// no reading position yet.
  final double? quranPercent;

  final bool? adhkarMorningDone;
  final bool? adhkarEveningDone;

  /// Arabic name of the next upcoming prayer (`PNAMES[key]`), e.g. `'العصر'`.
  /// Null when there's no valid schedule for today.
  final String? nextPrayerName;

  /// Cleaned `HH:MM` time of [nextPrayerName]. Null in lockstep with it.
  final String? nextPrayerTime;

  /// The concrete moment [nextPrayerName] occurs, for a live countdown.
  /// Null in lockstep with [nextPrayerName].
  final DateTime? nextPrayerAt;

  /// Arabic label of the last prayer marked complete today, walking
  /// fajr→isha (legacy has no explicit "last completed" field; this is the
  /// highest-order `true` flag in today's log). Null when nothing is marked
  /// yet today.
  final String? lastCompletedPrayerLabel;

  /// Saved prayer city (`S.prayer.city`), for empty-state messaging. Null
  /// when no city has been configured.
  final String? prayerLocationLabel;

  static const empty = HomeProgress();

  bool get hasStreak => streakDays != null && streakDays! > 0;
  bool get hasLastReading =>
      lastReadingLabel != null && lastReadingLabel!.trim().isNotEmpty;
  bool get hasPrayerSummary =>
      prayerCompletedToday != null && prayerTotalToday != null;
  bool get hasChallenge => completedChallengeDays != null;
  bool get hasTree =>
      treeStageLabel != null && treeStageLabel!.trim().isNotEmpty;
  bool get hasQuranProgress => quranPercent != null;
  bool get hasAdhkar => adhkarMorningDone != null || adhkarEveningDone != null;
  bool get hasNextPrayer => nextPrayerName != null && nextPrayerTime != null;
}
