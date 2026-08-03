import 'package:barakah40_flutter/features/quran/domain/entities/challenge_day.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/challenge_progress.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

/// Result of a completion/undo mutation attempt.
///
/// [changed] is `false` for a no-op (duplicate complete / undo of a day
/// that isn't done) — callers should skip persisting anything in that case.
class ChallengeDayMutationResult {
  const ChallengeDayMutationResult({
    required this.changed,
    required this.completed,
    required this.started,
    required this.completedAt,
  });

  factory ChallengeDayMutationResult.noop(UserAppState state) =>
      ChallengeDayMutationResult(
        changed: false,
        completed: state.completed,
        started: state.started,
        completedAt: state.extraMap('completedAt') ?? const {},
      );

  final bool changed;
  final List<bool> completed;
  final int? started;

  /// `S.completedAt` — index (as string key) -> epoch ms, kept in
  /// [UserAppState.extra] because it isn't one of the confirmed top-level
  /// fields yet.
  final Map<String, dynamic> completedAt;
}

/// Pure functions mirroring legacy `doneCount()`, `currentIdx()`,
/// `toggleDay()` and `#undoBtn` — no widget/controller/IO concerns.
///
/// Option A (legacy-faithful): none of these functions ever compute or
/// return an ayah range for a day. Completion is a plain manual flag.
abstract final class ChallengeProgressService {
  static int doneCount(List<bool> completed) =>
      completed.where((day) => day).length;

  /// First `false` index, or `completed.length` (40) if all are done.
  static int currentIdx(List<bool> completed) {
    final i = completed.indexOf(false);
    return i == -1 ? completed.length : i;
  }

  static bool canComplete(List<bool> completed, int index) {
    if (index < 0 || index >= completed.length) return false;
    return !completed[index];
  }

  static bool canUncomplete(List<bool> completed, int index) {
    if (index < 0 || index >= completed.length) return false;
    return completed[index];
  }

  /// Highest index with `completed[i] == true`, or `null` if none —
  /// mirrors legacy `#undoBtn`'s "undo the last done day" scan.
  static int? lastCompletedIndex(List<bool> completed) {
    var last = -1;
    for (var i = 0; i < completed.length; i++) {
      if (completed[i]) last = i;
    }
    return last == -1 ? null : last;
  }

  /// Marks day [index] complete. No-ops (mirrors legacy: completion is
  /// idempotent per day, re-confirming an already-done day changes nothing)
  /// when it's already `true`.
  static ChallengeDayMutationResult completeDay(
    UserAppState state,
    int index, {
    int? nowMs,
  }) {
    if (!canComplete(state.completed, index)) {
      return ChallengeDayMutationResult.noop(state);
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final nextCompleted = List<bool>.from(state.completed)..[index] = true;
    final completedAt = Map<String, dynamic>.from(
      state.extraMap('completedAt') ?? const {},
    )..['$index'] = now;
    return ChallengeDayMutationResult(
      changed: true,
      completed: nextCompleted,
      started: state.started ?? now,
      completedAt: completedAt,
    );
  }

  /// Undoes day [index] (legacy: tap a done day, or "undo last day"). No-op
  /// when that day isn't currently done.
  static ChallengeDayMutationResult uncompleteDay(
    UserAppState state,
    int index,
  ) {
    if (!canUncomplete(state.completed, index)) {
      return ChallengeDayMutationResult.noop(state);
    }
    final nextCompleted = List<bool>.from(state.completed)..[index] = false;
    final completedAt = Map<String, dynamic>.from(
      state.extraMap('completedAt') ?? const {},
    )..remove('$index');
    return ChallengeDayMutationResult(
      changed: true,
      completed: nextCompleted,
      started: state.started,
      completedAt: completedAt,
    );
  }

  /// Builds the full overview read-model. [surahEffectiveAyah] is
  /// `audioPos ?? lastAyah`, passed in by the caller so this stays a pure
  /// function of plain values.
  static ChallengeProgress buildProgress(
    UserAppState state, {
    int? surahEffectiveAyah,
  }) {
    final completed = state.completed;
    final idx = currentIdx(completed);
    final days = List<ChallengeDay>.generate(
      completed.length,
      (i) =>
          ChallengeDay(index: i, completed: completed[i], isCurrent: i == idx),
      growable: false,
    );

    double? surahPercent;
    if (surahEffectiveAyah != null && surahEffectiveAyah >= 1) {
      final clamped = surahEffectiveAyah.clamp(
        0,
        UserAppState.baqarahAyahCount,
      );
      surahPercent = clamped / UserAppState.baqarahAyahCount * 100;
    }

    return ChallengeProgress(
      completedDays: doneCount(completed),
      goalDays: completed.length,
      currentIndex: idx,
      days: days,
      started: state.started,
      surahPercent: surahPercent,
    );
  }
}
