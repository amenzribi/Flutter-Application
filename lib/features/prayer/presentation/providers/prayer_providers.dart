import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';
import 'package:barakah40_flutter/features/prayer/data/repositories/aladhan_prayer_times_repository.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_day_progress.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_streak_service.dart';
import 'package:barakah40_flutter/features/prayer/presentation/controllers/prayer_schedule_controller.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>((ref) {
  return AladhanPrayerTimesRepository();
});

final prayerLocationServiceProvider = Provider<PrayerLocationService>((ref) {
  return const GeolocatorPrayerLocationService();
});

/// Screen-scoped: instantiating it kicks off [PrayerScheduleController]'s
/// cache/city/GPS pipeline (legacy "on prayer view open" hook), and
/// disposing the prayer screen tears it down again rather than leaving a
/// GPS lookup running in the background.
final prayerScheduleControllerProvider =
    StateNotifierProvider.autoDispose<
      PrayerScheduleController,
      PrayerScheduleState
    >((ref) {
      return PrayerScheduleController(
        ref,
        repository: ref.watch(prayerTimesRepositoryProvider),
        locationService: ref.watch(prayerLocationServiceProvider),
      );
    });

/// Today's five-prayer completion summary (legacy `dayRec(dayKey())`).
final prayerDayProgressProvider = Provider<PrayerDayProgress>((ref) {
  final settings = ref.watch(userAppStateProvider).prayer;
  final today = PrayerDayKey.dayKey();
  return PrayerDayProgress.fromRecord(settings.recordFor(today));
});

/// Current/longest full-day streak (legacy `currentStreak()`/`longestStreak()`).
class PrayerStreakSummary {
  const PrayerStreakSummary({required this.current, required this.longest});

  final int current;
  final int longest;
}

final prayerStreakProvider = Provider<PrayerStreakSummary>((ref) {
  final log = ref.watch(userAppStateProvider).prayer.log;
  return PrayerStreakSummary(
    current: PrayerStreakService.currentStreak(log),
    longest: PrayerStreakService.longestStreak(log),
  );
});
