import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/home/domain/services/hijri_date.dart';
import 'package:barakah40_flutter/features/home/domain/services/home_greeting.dart';
import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';

void main() {
  group('HomeGreeting', () {
    test('morning greeting', () {
      expect(HomeGreeting.forDateTime(DateTime(2026, 8, 3, 8)), 'صباح الخير');
    });

    test('includes display name when provided', () {
      expect(
        HomeGreeting.forDateTime(DateTime(2026, 8, 3, 8), displayName: 'نورة'),
        'صباح الخير، نورة',
      );
    });
  });

  group('HijriDate', () {
    test('formats Arabic Hijri label', () {
      final hijri = HijriDate.fromGregorian(DateTime(2026, 8, 3));
      expect(hijri.formatAr(), contains('هـ'));
      expect(hijri.year, greaterThan(1400));
      expect(hijri.month, inInclusiveRange(1, 12));
      expect(hijri.day, inInclusiveRange(1, 30));
    });
  });

  group('HomeProgress', () {
    test('empty snapshot reports no tracked data', () {
      const progress = HomeProgress.empty;
      expect(progress.hasStreak, isFalse);
      expect(progress.hasLastReading, isFalse);
      expect(progress.hasPrayerSummary, isFalse);
      expect(progress.hasChallenge, isFalse);
      expect(progress.hasTree, isFalse);
      expect(progress.hasQuranProgress, isFalse);
      expect(progress.hasAdhkar, isFalse);
    });

    test('does not invent streak from zero', () {
      const progress = HomeProgress(streakDays: 0);
      expect(progress.hasStreak, isFalse);
    });
  });
}
