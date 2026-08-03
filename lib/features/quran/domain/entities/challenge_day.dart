/// One cell of the 40-day Al-Baqarah challenge grid.
///
/// Option A (legacy-faithful): this only ever describes completion state,
/// never an ayah range — there is no per-day reading assignment.
class ChallengeDay {
  const ChallengeDay({
    required this.index,
    required this.completed,
    required this.isCurrent,
  });

  /// 0-based index into `S.completed` (0..39).
  final int index;

  final bool completed;

  /// Whether this is the next day to complete (legacy `currentIdx()`).
  final bool isCurrent;

  /// 1-based day number for display ("اليوم N").
  int get displayNumber => index + 1;
}
