import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/features/user_state/data/repositories/shared_preferences_user_state_repository.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesUserStateRepository', () {
    test('load returns defaults when nothing stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesUserStateRepository(prefs);

      final state = await repo.load('uid-1');
      expect(state.completed, List<bool>.filled(40, false));
      expect(state.lang, 'ar');
    });

    test('save then load round-trips confirmed and unknown fields', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesUserStateRepository(prefs);

      final completed = List<bool>.filled(40, false)
        ..[0] = true
        ..[1] = true;
      final original = UserAppState.defaults().copyWith(
        completed: completed,
        lastAyah: 12,
        lang: 'en',
        extra: {
          'tree': {'shownStage': 2},
        },
      );

      await repo.save('uid-1', original);
      final loaded = await repo.load('uid-1');

      expect(loaded.completed, completed);
      expect(loaded.lastAyah, 12);
      expect(loaded.lang, 'en');
      expect(loaded.extra['tree'], {'shownStage': 2});
    });

    test(
      'account isolation — different uids never see each other\'s state',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SharedPreferencesUserStateRepository(prefs);

        await repo.save('uid-a', UserAppState.defaults().copyWith(lang: 'en'));
        await repo.save('uid-b', UserAppState.defaults().copyWith(lang: 'ar'));

        final a = await repo.load('uid-a');
        final b = await repo.load('uid-b');

        expect(a.lang, 'en');
        expect(b.lang, 'ar');
        expect(
          prefs.getKeys(),
          containsAll(<String>[
            SharedPreferencesUserStateRepository.keyFor('uid-a'),
            SharedPreferencesUserStateRepository.keyFor('uid-b'),
          ]),
        );
      },
    );

    test(
      'corrupt stored JSON recovers to defaults and overwrites the bad entry',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesUserStateRepository.keyFor('uid-1'):
              '{not-valid-json',
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = SharedPreferencesUserStateRepository(prefs);

        final state = await repo.load('uid-1');
        expect(state.completed, List<bool>.filled(40, false));
        expect(state.lang, 'ar');

        // Recovery persisted the fresh defaults, so a second read is clean.
        final key = SharedPreferencesUserStateRepository.keyFor('uid-1');
        expect(prefs.getString(key), isNot('{not-valid-json'));
        final second = await repo.load('uid-1');
        expect(second.lang, 'ar');
      },
    );

    test('non-object JSON (array) is treated as corrupt', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesUserStateRepository.keyFor('uid-1'): '[1,2,3]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesUserStateRepository(prefs);

      final state = await repo.load('uid-1');
      expect(state.completed, List<bool>.filled(40, false));
    });

    test('empty string stored value is treated as "nothing stored"', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesUserStateRepository.keyFor('uid-1'): '',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesUserStateRepository(prefs);

      final state = await repo.load('uid-1');
      expect(state.completed, List<bool>.filled(40, false));
    });

    test('clear removes the stored entry', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesUserStateRepository(prefs);

      await repo.save('uid-1', UserAppState.defaults());
      expect(
        prefs.getString(SharedPreferencesUserStateRepository.keyFor('uid-1')),
        isNotNull,
      );

      await repo.clear('uid-1');
      expect(
        prefs.getString(SharedPreferencesUserStateRepository.keyFor('uid-1')),
        isNull,
      );
    });
  });
}
