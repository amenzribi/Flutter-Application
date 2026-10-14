import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/home/data/repositories/home_repository_impl.dart';
import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';
import 'package:barakah40_flutter/features/home/domain/repositories/home_repository.dart';
import 'package:barakah40_flutter/features/home/domain/services/day_part.dart';
import 'package:barakah40_flutter/features/home/domain/services/hijri_date.dart';
import 'package:barakah40_flutter/features/home/domain/services/home_progress_mapper.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/daily_prayer_schedule.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/home/domain/services/home_greeting.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final controller = ref.watch(userStateControllerProvider.notifier);
  return HomeRepositoryImpl(controller);
});

/// Ticks about once a minute for live clock / greeting updates.
final homeClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );
});

final homeProgressProvider = StreamProvider<HomeProgress>((ref) {
  return ref.watch(homeRepositoryProvider).watchProgress();
});

class HomeDashboardViewModel {
  const HomeDashboardViewModel({
    required this.now,
    required this.user,
    required this.progress,
    required this.greeting,
    required this.timeLabel,
    required this.gregorianLabel,
    required this.hijriLabel,
  });

  final DateTime now;
  final AppUser? user;
  final HomeProgress progress;
  final String greeting;
  final String timeLabel;
  final String gregorianLabel;
  final String hijriLabel;
}

final homeDashboardProvider = Provider<AsyncValue<HomeDashboardViewModel>>((
  ref,
) {
  final clock = ref.watch(homeClockProvider);
  final state = ref.watch(userAppStateProvider);
  final user = ref.watch(currentUserProvider);

  return clock.when(
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
    data: (now) {
      // Mapped on every clock tick too, so the next prayer moves on once it
      // passes and today's prayer count resets after midnight.
      final homeProgress = HomeProgressMapper.map(state, now: now);
      final timeLabel = DateFormat('h:mm a', 'en').format(now);
      final gregorianLabel = DateFormat('EEEE d MMMM y', 'ar').format(now);
      final hijriLabel = HijriDate.fromGregorian(now).formatAr();
      final greeting = HomeGreeting.forDateTime(
        now,
        displayName: user?.displayName,
      );
      return AsyncData(
        HomeDashboardViewModel(
          now: now,
          user: user,
          progress: homeProgress,
          greeting: greeting,
          timeLabel: timeLabel,
          gregorianLabel: gregorianLabel,
          hijriLabel: hijriLabel,
        ),
      );
    },
  );
});

/// Current legacy day period (time-of-day background + greeting).
final dayPeriodProvider = Provider<DayPart>((ref) {
  final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
  final prayer = ref.watch(userAppStateProvider.select((s) => s.prayer));
  final schedule = DailyPrayerSchedule.fromSettings(
    prayer,
    PrayerDayKey.dayKey(now),
  );
  return DayPart.of(now, schedule: schedule);
});
