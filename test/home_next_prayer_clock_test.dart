import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test(
    'home next prayer moves on as time passes, without a state change',
    () async {
      final morning = DateTime(2026, 10, 14, 12, 50);
      final clock = StreamController<DateTime>();
      addTearDown(clock.close);
      final container = ProviderContainer(
        overrides: [
          homeClockProvider.overrideWith((ref) => clock.stream),
          currentUserProvider.overrideWithValue(null),
          userAppStateProvider.overrideWithValue(
            UserAppState.defaults().copyWith(
              prayer: PrayerSettings(
                timesDate: PrayerDayKey.dayKey(morning),
                times: const {
                  'fajr': '05:40',
                  'dhuhr': '12:54',
                  'asr': '16:11',
                  'maghrib': '18:38',
                  'isha': '19:58',
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(homeDashboardProvider, (_, _) {});
      addTearDown(sub.close);

      clock.add(morning);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(homeDashboardProvider).value!.progress.nextPrayerTime,
        '12:54',
      );

      clock.add(DateTime(2026, 10, 14, 13, 0));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(homeDashboardProvider).value!.progress.nextPrayerTime,
        '16:11',
      );
    },
  );
}
