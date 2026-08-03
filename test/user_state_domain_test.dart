import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

void main() {
  group('UserAppState.defaults', () {
    test('matches legacy defaults object', () {
      final state = UserAppState.defaults();

      expect(state.completed, List<bool>.filled(40, false));
      expect(state.lastAyah, isNull);
      expect(state.palette, 'offwhite');
      expect(state.qscale, 1.0);
      expect(state.intention, isEmpty);
      expect(state.journal, isEmpty);
      expect(state.adhkarCount, isEmpty);
      expect(state.reminder.enabled, isFalse);
      expect(state.reminder.morning, '06:30');
      expect(state.reminder.evening, '18:30');
      expect(state.reminder.baqarah, '20:00');
      expect(state.reminder.prayer, isTrue);
      expect(state.started, isNull);
      expect(state.seen, isFalse);
      expect(state.guest, isFalse);
      expect(state.reciter, 'Alafasy_128kbps');
      expect(state.audioPos, isNull);
      expect(state.prayer.log, isEmpty);
      expect(state.prayer.city, '');
      expect(state.prayer.country, '');
      expect(state.prayer.method, 5);
      expect(state.prayer.times, isEmpty);
      expect(state.prayer.timesDate, '');
      expect(state.qibla.lat, isNull);
      expect(state.qibla.lng, isNull);
      expect(state.qibla.city, '');
      expect(state.tasbeeh.count, 0);
      expect(state.tasbeeh.target, 0);
      expect(state.lang, 'ar');
      expect(state.extra, isEmpty);
    });
  });

  group('UserAppState.fromJson — missing/null handling', () {
    test('empty json yields full defaults', () {
      final state = UserAppState.fromJson(const {});
      expect(state.completed, List<bool>.filled(40, false));
      expect(state.lang, 'ar');
      expect(state.reminder.morning, '06:30');
    });

    test('null json yields full defaults', () {
      final state = UserAppState.fromJson(null);
      expect(state.completed, List<bool>.filled(40, false));
      expect(state.lang, 'ar');
    });

    test('explicit null confirmed fields fall back per-field to defaults', () {
      final state = UserAppState.fromJson({
        'completed': null,
        'lang': null,
        'qscale': null,
        'reminder': null,
        'prayer': null,
      });
      expect(state.completed, List<bool>.filled(40, false));
      expect(state.lang, 'ar');
      expect(state.qscale, 1.0);
      expect(state.reminder.morning, '06:30');
      expect(state.prayer.method, 5);
    });

    test(
      'wrong-typed values fall back to field defaults instead of throwing',
      () {
        final state = UserAppState.fromJson({
          'completed': 'not-a-list',
          'qscale': 'not-a-number',
          'guest': 'not-a-bool',
          'adhkarCount': 'not-a-map',
          'lastAyah': 'not-an-int',
        });
        expect(state.completed, List<bool>.filled(40, false));
        expect(state.qscale, 1.0);
        expect(state.guest, isFalse);
        expect(state.adhkarCount, isEmpty);
        expect(state.lastAyah, isNull);
      },
    );

    test('reminder deep-fills missing sub-fields like legacy merge', () {
      final state = UserAppState.fromJson({
        'reminder': {'enabled': true},
      });
      expect(state.reminder.enabled, isTrue);
      expect(state.reminder.morning, '06:30');
      expect(state.reminder.evening, '18:30');
      expect(state.reminder.baqarah, '20:00');
      expect(state.reminder.prayer, isTrue);
    });

    test('lastAyah round-trips as a plain global ayah number', () {
      final state = UserAppState.fromJson({'lastAyah': 57});
      expect(state.lastAyah, 57);
      expect(state.toJson()['lastAyah'], 57);
    });
  });

  group('UserAppState.fromJson — unknown key preservation', () {
    test('preserves unknown/partial top-level keys in extra', () {
      final json = {
        'completed': List<bool>.filled(40, false),
        'lang': 'ar',
        'tree': {'shownStage': 3, 'stageDay': '2026-08-03'},
        'stats': {'listenSec': 42},
        'name': 'نورة',
        'someBrandNewFutureField': 'value',
      };
      final state = UserAppState.fromJson(json);

      expect(state.extra['tree'], {'shownStage': 3, 'stageDay': '2026-08-03'});
      expect(state.extra['stats'], {'listenSec': 42});
      expect(state.extra['name'], 'نورة');
      expect(state.extra['someBrandNewFutureField'], 'value');
      // Confirmed fields must never leak into extra.
      expect(state.extra.containsKey('completed'), isFalse);
      expect(state.extra.containsKey('lang'), isFalse);
    });

    test('round-trips unknown keys through toJson unchanged', () {
      final json = {
        'tree': {'shownStage': 3},
        'unknownFutureField': 42,
      };
      final roundTripped = UserAppState.fromJson(json).toJson();
      expect(roundTripped['tree'], {'shownStage': 3});
      expect(roundTripped['unknownFutureField'], 42);
      // Confirmed fields are always present even if absent from source json.
      expect(roundTripped['completed'], List<bool>.filled(40, false));
      expect(roundTripped['lang'], 'ar');
    });
  });

  group('UserAppState.copyWith / copyWithExtra', () {
    test('copyWith changes only the targeted field', () {
      final base = UserAppState.defaults();
      final next = base.copyWith(lang: 'en');

      expect(next.lang, 'en');
      expect(next.completed, base.completed);
      expect(base.lang, 'ar'); // original untouched (immutability)
    });

    test('copyWithExtra sets and removes a single extra key', () {
      final base = UserAppState.defaults();
      final withTree = base.copyWithExtra('tree', {'shownStage': 1});
      expect(withTree.extraMap('tree'), {'shownStage': 1});

      final removed = withTree.copyWithExtra('tree', null);
      expect(removed.extra.containsKey('tree'), isFalse);
    });

    test('extraMap returns null for absent or non-map keys', () {
      final state = UserAppState.defaults().copyWithExtra('name', 'نورة');
      expect(state.extraMap('tree'), isNull);
      expect(state.extraMap('name'), isNull); // not a map
    });
  });
}
