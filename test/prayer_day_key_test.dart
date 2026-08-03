import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';

void main() {
  group('PrayerDayKey.dayKey', () {
    test('pads single-digit month and day with a leading zero', () {
      expect(PrayerDayKey.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('does not pad already double-digit month and day', () {
      expect(PrayerDayKey.dayKey(DateTime(2026, 12, 25)), '2026-12-25');
    });

    test('ignores the time-of-day component', () {
      expect(
        PrayerDayKey.dayKey(DateTime(2026, 8, 4, 23, 59, 59)),
        '2026-08-04',
      );
    });

    test('defaults to DateTime.now() when no argument is given', () {
      final now = DateTime.now();
      String pad(int value) => value.toString().padLeft(2, '0');
      expect(
        PrayerDayKey.dayKey(),
        '${now.year}-${pad(now.month)}-${pad(now.day)}',
      );
    });
  });
}
