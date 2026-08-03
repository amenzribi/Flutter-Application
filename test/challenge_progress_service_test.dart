import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/quran/domain/services/challenge_progress_service.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

void main() {
  group('doneCount / currentIdx', () {
    test('doneCount is 0 for a fresh 40-day challenge', () {
      expect(
        ChallengeProgressService.doneCount(List<bool>.filled(40, false)),
        0,
      );
    });

    test('currentIdx is 0 when nothing is done', () {
      expect(
        ChallengeProgressService.currentIdx(List<bool>.filled(40, false)),
        0,
      );
    });

    test('currentIdx is the first false index for a contiguous prefix', () {
      final completed = List<bool>.filled(40, false)
        ..[0] = true
        ..[1] = true
        ..[2] = true;
      expect(ChallengeProgressService.currentIdx(completed), 3);
      expect(ChallengeProgressService.doneCount(completed), 3);
    });

    test('currentIdx is the first false index even with a later gap', () {
      // Non-contiguous completion: day 5 done but day 0 isn't — legacy
      // still reports the FIRST false index, not the count of done days.
      final completed = List<bool>.filled(40, false)..[5] = true;
      expect(ChallengeProgressService.currentIdx(completed), 0);
      expect(ChallengeProgressService.doneCount(completed), 1);
    });

    test('currentIdx is 40 (goalDays) once every day is done', () {
      final completed = List<bool>.filled(40, true);
      expect(ChallengeProgressService.currentIdx(completed), 40);
      expect(ChallengeProgressService.doneCount(completed), 40);
    });
  });

  group('canComplete / canUncomplete', () {
    test('canComplete is true only for a not-yet-done day', () {
      final completed = List<bool>.filled(40, false)..[0] = true;
      expect(ChallengeProgressService.canComplete(completed, 0), isFalse);
      expect(ChallengeProgressService.canComplete(completed, 1), isTrue);
    });

    test('canUncomplete is true only for an already-done day', () {
      final completed = List<bool>.filled(40, false)..[0] = true;
      expect(ChallengeProgressService.canUncomplete(completed, 0), isTrue);
      expect(ChallengeProgressService.canUncomplete(completed, 1), isFalse);
    });

    test('out-of-range indices are rejected by both', () {
      final completed = List<bool>.filled(40, false);
      expect(ChallengeProgressService.canComplete(completed, -1), isFalse);
      expect(ChallengeProgressService.canComplete(completed, 40), isFalse);
      expect(ChallengeProgressService.canUncomplete(completed, -1), isFalse);
      expect(ChallengeProgressService.canUncomplete(completed, 40), isFalse);
    });
  });

  group('completeDay', () {
    test(
      'marks the day done, starts the challenge, and stamps completedAt',
      () {
        final state = UserAppState.defaults();

        final result = ChallengeProgressService.completeDay(
          state,
          3,
          nowMs: 1000,
        );

        expect(result.changed, isTrue);
        expect(result.completed[3], isTrue);
        expect(result.completed.where((d) => d).length, 1);
        expect(result.started, 1000);
        expect(result.completedAt['3'], 1000);
      },
    );

    test('does not overwrite an already-set started time', () {
      final state = UserAppState.defaults().copyWith(started: 500);

      final result = ChallengeProgressService.completeDay(
        state,
        0,
        nowMs: 9999,
      );

      expect(result.started, 500);
    });

    test('completing an already-done day is a no-op (duplicate-safe)', () {
      final completed = List<bool>.filled(40, false)..[2] = true;
      final state = UserAppState.defaults().copyWith(
        completed: completed,
        started: 100,
      );

      final result = ChallengeProgressService.completeDay(
        state,
        2,
        nowMs: 5000,
      );

      expect(result.changed, isFalse);
      expect(result.completed, completed);
      expect(result.started, 100);
      expect(result.completedAt, isEmpty);
    });

    test('preserves completedAt entries for other days', () {
      final state = UserAppState.defaults().copyWithExtra('completedAt', {
        '0': 111,
      });

      final result = ChallengeProgressService.completeDay(state, 1, nowMs: 222);

      expect(result.completedAt, {'0': 111, '1': 222});
    });
  });

  group('uncompleteDay (undo)', () {
    test('undoes a completed day and removes its completedAt stamp', () {
      final completed = List<bool>.filled(40, false)..[4] = true;
      final state = UserAppState.defaults()
          .copyWith(completed: completed, started: 100)
          .copyWithExtra('completedAt', {'4': 555});

      final result = ChallengeProgressService.uncompleteDay(state, 4);

      expect(result.changed, isTrue);
      expect(result.completed[4], isFalse);
      expect(result.completedAt.containsKey('4'), isFalse);
      // Undo never clears the overall challenge start time.
      expect(result.started, 100);
    });

    test('undoing a day that is not done is a no-op', () {
      final state = UserAppState.defaults();

      final result = ChallengeProgressService.uncompleteDay(state, 0);

      expect(result.changed, isFalse);
      expect(result.completed, state.completed);
    });

    test('complete then undo returns to the original all-false state', () {
      final state = UserAppState.defaults();

      final completed = ChallengeProgressService.completeDay(
        state,
        7,
        nowMs: 1,
      );
      final withDay = state.copyWith(
        completed: completed.completed,
        started: completed.started,
      );

      final undone = ChallengeProgressService.uncompleteDay(withDay, 7);

      expect(undone.completed, List<bool>.filled(40, false));
    });
  });

  group('lastCompletedIndex', () {
    test('null when nothing is completed', () {
      expect(
        ChallengeProgressService.lastCompletedIndex(
          List<bool>.filled(40, false),
        ),
        isNull,
      );
    });

    test('returns the highest completed index for #undoBtn-style undo', () {
      final completed = List<bool>.filled(40, false)
        ..[0] = true
        ..[3] = true
        ..[1] = true;
      expect(ChallengeProgressService.lastCompletedIndex(completed), 3);
    });
  });

  group('buildProgress', () {
    test('builds a full day list with the correct isCurrent flag', () {
      final completed = List<bool>.filled(40, false)
        ..[0] = true
        ..[1] = true;
      final state = UserAppState.defaults().copyWith(
        completed: completed,
        started: 42,
      );

      final progress = ChallengeProgressService.buildProgress(state);

      expect(progress.completedDays, 2);
      expect(progress.goalDays, 40);
      expect(progress.currentIndex, 2);
      expect(progress.started, 42);
      expect(progress.days, hasLength(40));
      expect(progress.days[0].completed, isTrue);
      expect(progress.days[0].isCurrent, isFalse);
      expect(progress.days[2].completed, isFalse);
      expect(progress.days[2].isCurrent, isTrue);
      expect(progress.days[2].displayNumber, 3);
      expect(progress.dayPercent, closeTo(2 / 40 * 100, 0.001));
      expect(progress.isComplete, isFalse);
    });

    test('surahPercent is null with no reading position (never invented)', () {
      final progress = ChallengeProgressService.buildProgress(
        UserAppState.defaults(),
      );
      expect(progress.surahPercent, isNull);
    });

    test(
      'surahPercent reflects the effective ayah position, clamped to 286',
      () {
        final progress = ChallengeProgressService.buildProgress(
          UserAppState.defaults(),
          surahEffectiveAyah: 143,
        );
        expect(progress.surahPercent, closeTo(143 / 286 * 100, 0.001));
      },
    );

    test(
      'a fully completed challenge reports isComplete and no current day',
      () {
        final state = UserAppState.defaults().copyWith(
          completed: List<bool>.filled(40, true),
        );
        final progress = ChallengeProgressService.buildProgress(state);

        expect(progress.isComplete, isTrue);
        expect(progress.currentIndex, 40);
        expect(progress.days.every((d) => !d.isCurrent), isTrue);
      },
    );
  });
}
