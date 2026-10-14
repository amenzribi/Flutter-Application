import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/features/prayer/data/notifications/adhan_notifier.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/daily_prayer_schedule.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/next_prayer_service.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

final adhanNotifierProvider = Provider<AdhanNotifier>((ref) => AdhanNotifier());

/// Legacy `S.reminder.enabled && S.reminder.prayer`.
final adhanAlertsEnabledProvider = Provider<bool>((ref) {
  final reminder = ref.watch(userAppStateProvider.select((s) => s.reminder));
  return reminder.enabled && reminder.prayer;
});

/// Clock used by the scheduler; overridden in tests.
final adhanClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// What the scheduler is waiting for, exposed for tests.
class AdhanPlan {
  const AdhanPlan({required this.wakeAt, this.prayer});

  /// When the timer fires.
  final DateTime wakeAt;

  /// The prayer announced at [wakeAt]; null when the timer only refreshes
  /// the times (after midnight, or after a failed fetch).
  final PrayerName? prayer;
}

String adhanTitle(PrayerName prayer) =>
    'حان الآن موعد أذان ${prayer.arabicLabel}';

const adhanBody = 'قومي إلى الصلاة، تقبّل الله منكِ';

/// Alerts at each prayer time while the app is open. Kept alive by the
/// signed-in shell. Today's times come from the saved schedule; when they are
/// missing (new day) they are fetched again for the saved city or location.
final adhanAlertProvider = Provider<AdhanPlan?>((ref) {
  if (!ref.watch(adhanAlertsEnabledProvider)) return null;
  final notifier = ref.watch(adhanNotifierProvider);
  if (!notifier.supported) return null;

  final prayer = ref.watch(userAppStateProvider.select((s) => s.prayer));
  final hasPlace = prayer.city.trim().isNotEmpty || prayer.extra['lat'] is num;
  if (!hasPlace) return null; // never ask for GPS from here
  // Keeps the schedule controller alive; it fetches today's times on start.
  ref.listen(prayerScheduleControllerProvider, (_, _) {});

  final now = ref.watch(adhanClockProvider)();
  final schedule = DailyPrayerSchedule.fromSettings(
    prayer,
    PrayerDayKey.dayKey(now),
  );

  final AdhanPlan plan;
  if (!schedule.hasFajr) {
    // New day or failed fetch: ask for today's times, retry later.
    Future.microtask(
      () => ref.read(prayerScheduleControllerProvider.notifier).refresh(),
    );
    plan = AdhanPlan(wakeAt: now.add(const Duration(minutes: 15)));
  } else {
    final next = NextPrayerService.nextPrayerInfo(schedule.times, now);
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    plan = next == null || !next.at.isBefore(midnight)
        // After Isha: wake after midnight to load the new day's times.
        ? AdhanPlan(wakeAt: midnight)
        : AdhanPlan(wakeAt: next.at, prayer: next.name);
  }

  final timer = Timer(plan.wakeAt.difference(now), () {
    final due = plan.prayer;
    if (due != null) notifier.show(title: adhanTitle(due), body: adhanBody);
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return plan;
});
