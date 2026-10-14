import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_streak_service.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_prayer_location_service.dart';
import 'fakes/fake_prayer_times_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

Future<void> settle([int ticks = 12]) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _times = PrayerTimesFetchResult(
  times: {
    PrayerName.fajr: '05:40',
    PrayerName.dhuhr: '12:54',
    PrayerName.asr: '16:11',
    PrayerName.maghrib: '18:38',
    PrayerName.isha: '19:58',
  },
  timezone: 'Africa/Cairo',
);

void main() {
  late FakeAuthRepository auth;
  late FakeUserStateLocalRepository local;
  late FakeUserStateRemoteRepository remote;
  late FakePrayerTimesRepository prayerRepo;
  late ProviderContainer container;

  Future<void> start(UserAppState seeded) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    auth = FakeAuthRepository();
    local = FakeUserStateLocalRepository()..seed('u1', seeded);
    remote = FakeUserStateRemoteRepository();
    prayerRepo = FakePrayerTimesRepository(
      byCityResult: _times,
      byCoordinatesResult: _times,
    );
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sharedPreferencesProvider.overrideWithValue(prefs),
        userStateLocalRepositoryProvider.overrideWithValue(local),
        userStateRemoteRepositoryProvider.overrideWithValue(remote),
        prayerTimesRepositoryProvider.overrideWithValue(prayerRepo),
        prayerLocationServiceProvider.overrideWithValue(
          FakePrayerLocationService(PrayerLocationResult.permissionDenied()),
        ),
      ],
    );
    addTearDown(() {
      auth.dispose();
      remote.dispose();
      container.dispose();
    });
    container.read(userStateControllerProvider.notifier);
    auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
    await settle();
  }

  test('after a GPS fix, the next day fetches by coordinates, not by the '
      'time-zone city name', () async {
    await start(
      UserAppState.defaults().copyWith(
        prayer: const PrayerSettings(
          city: 'Cairo', // time-zone label saved by the GPS path
          timesDate: '2000-01-01', // stale: a new day
          extra: {'lat': 24.09, 'lng': 32.9, 'tz': 'Africa/Cairo'}, // Aswan
        ),
      ),
    );
    container.read(prayerScheduleControllerProvider);
    await settle(30);
    expect(prayerRepo.coordinatesCalls, 1);
    expect(prayerRepo.cityCalls, 0);
  });

  test('choosing a city by hand clears the GPS coordinates', () async {
    await start(
      UserAppState.defaults().copyWith(
        prayer: const PrayerSettings(
          city: 'Cairo',
          extra: {'lat': 24.09, 'lng': 32.9, 'tz': 'Africa/Cairo'},
        ),
      ),
    );
    container
        .read(userStateControllerProvider.notifier)
        .setPrayerCity(city: 'Aswan', country: 'Egypt');
    final prayer = container.read(userAppStateProvider).prayer;
    expect(prayer.city, 'Aswan');
    expect(prayer.extra.containsKey('lat'), isFalse);
    expect(prayer.extra.containsKey('lng'), isFalse);
  });

  test('a GPS fix gives the qibla a location when it has none', () async {
    await start(UserAppState.defaults());
    container
        .read(userStateControllerProvider.notifier)
        .applyPrayerSchedule(
          times: _times.times,
          timesDate: '2026-10-14',
          city: 'Tripoli',
          lat: 32.88,
          lng: 13.19,
        );
    final qibla = container.read(userAppStateProvider).qibla;
    expect(qibla.lat, 32.88);
    expect(qibla.city, 'موقعي الحالي');
  });

  test('streaks count calendar days across a daylight-saving change', () {
    final full = {for (final n in PrayerName.values) n.key: true};
    // 25 October 2026 is a 25-hour day in Europe (clocks go back).
    final log = <String, dynamic>{
      '2026-10-24': full,
      '2026-10-25': full,
      '2026-10-26': full,
      '2026-10-27': full,
    };
    expect(PrayerStreakService.longestStreak(log), 4);
    expect(
      PrayerStreakService.currentStreak(
        log,
        now: DateTime(2026, 10, 27, 23, 30),
      ),
      4,
    );
    expect(
      PrayerStreakService.currentStreak(
        log,
        now: DateTime(2026, 10, 28, 0, 30),
      ),
      4,
    );
  });
}
