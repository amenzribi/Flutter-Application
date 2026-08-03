import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/prayer/domain/services/prayer_tracking_service.dart';

void main() {
  group('PrayerTrackingService.togglePrayer', () {
    test('toggling an unset key marks it true', () {
      final result = PrayerTrackingService.togglePrayer(
        const {},
        '2026-08-04',
        'fajr',
      );
      expect(result['2026-08-04']['fajr'], isTrue);
    });

    test('toggling twice (duplicate mark) turns it back off', () {
      final once = PrayerTrackingService.togglePrayer(
        const {},
        '2026-08-04',
        'fajr',
      );
      final twice = PrayerTrackingService.togglePrayer(
        once,
        '2026-08-04',
        'fajr',
      );
      expect(twice['2026-08-04']['fajr'], isFalse);
    });

    test('does not mutate the original log', () {
      final original = <String, dynamic>{};
      PrayerTrackingService.togglePrayer(original, '2026-08-04', 'fajr');
      expect(original, isEmpty);
    });

    test('preserves other prayers already recorded for the day', () {
      final log = {
        '2026-08-04': {'fajr': true},
      };
      final result = PrayerTrackingService.togglePrayer(
        log,
        '2026-08-04',
        'dhuhr',
      );
      expect(result['2026-08-04']['fajr'], isTrue);
      expect(result['2026-08-04']['dhuhr'], isTrue);
    });

    test('does not touch other days in the log', () {
      final log = {
        '2026-08-03': {'fajr': true},
      };
      final result = PrayerTrackingService.togglePrayer(
        log,
        '2026-08-04',
        'fajr',
      );
      expect(result['2026-08-03']['fajr'], isTrue);
      expect(result['2026-08-04']['fajr'], isTrue);
    });

    test('is a no-op (identical map) for an unrecognized prayer key', () {
      final log = {
        '2026-08-04': {'fajr': true},
      };
      final result = PrayerTrackingService.togglePrayer(
        log,
        '2026-08-04',
        'not-a-prayer',
      );
      expect(identical(result, log), isTrue);
    });

    test('is a no-op for an empty key', () {
      final log = <String, dynamic>{};
      final result = PrayerTrackingService.togglePrayer(log, '2026-08-04', '');
      expect(identical(result, log), isTrue);
    });
  });
}
