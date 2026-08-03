import 'package:barakah40_flutter/features/quran/domain/entities/challenge_day.dart';

/// Read-model for the 40-day challenge overview screen, built by
/// `ChallengeProgressService.buildProgress`.
///
/// Deliberately keeps the day-completion percentage ([dayPercent], driven
/// by `S.completed`) separate from the mushaf reading percentage
/// ([surahPercent], driven by `S.lastAyah`/`S.audioPos`) — legacy never
/// conflates the two (see `FLUTTER_QURAN_CHALLENGE.md` §5).
class ChallengeProgress {
  const ChallengeProgress({
    required this.completedDays,
    this.goalDays = 40,
    required this.currentIndex,
    required this.days,
    this.started,
    this.surahPercent,
  });

  /// `doneCount()` — number of `true` flags in `S.completed`.
  final int completedDays;

  /// Challenge length; always 40 in production (`S.completed.length`).
  final int goalDays;

  /// `currentIdx()` — first `false` index, or [goalDays] once all done.
  final int currentIndex;

  final List<ChallengeDay> days;

  /// Epoch ms the challenge started (`S.started`), or `null`.
  final int? started;

  /// Al-Baqarah reading percent (0..100) from the current position, or
  /// `null` when there's no position yet. Never derived from [completedDays].
  final double? surahPercent;

  bool get isComplete => completedDays >= goalDays;

  /// `round(done/40*100)`.
  double get dayPercent => goalDays == 0 ? 0 : (completedDays / goalDays) * 100;
}
