/// Snapshot of home dashboard progress. Null/empty fields mean no data yet.
class HomeProgress {
  const HomeProgress({
    this.streakDays,
    this.lastReadingLabel,
    this.prayerCompletedToday,
    this.prayerTotalToday,
    this.challengeDay,
    this.challengeGoalDays = 40,
    this.treeStageLabel,
    this.quranPercent,
    this.adhkarMorningDone,
    this.adhkarEveningDone,
  });

  /// Consecutive active days. Null = never started.
  final int? streakDays;

  /// Human label for last Quran position, e.g. "البقرة ٢:١٥". Null = none.
  final String? lastReadingLabel;

  final int? prayerCompletedToday;
  final int? prayerTotalToday;

  /// Challenge day index 1..40. Null = challenge not started.
  final int? challengeDay;
  final int challengeGoalDays;

  /// Living tree stage label. Null = garden not started.
  final String? treeStageLabel;

  /// 0..100 Quran completion if tracked. Null = none.
  final double? quranPercent;

  final bool? adhkarMorningDone;
  final bool? adhkarEveningDone;

  static const empty = HomeProgress();

  bool get hasStreak => streakDays != null && streakDays! > 0;
  bool get hasLastReading =>
      lastReadingLabel != null && lastReadingLabel!.trim().isNotEmpty;
  bool get hasPrayerSummary =>
      prayerCompletedToday != null && prayerTotalToday != null;
  bool get hasChallenge => challengeDay != null;
  bool get hasTree =>
      treeStageLabel != null && treeStageLabel!.trim().isNotEmpty;
  bool get hasQuranProgress => quranPercent != null;
  bool get hasAdhkar => adhkarMorningDone != null || adhkarEveningDone != null;
}
