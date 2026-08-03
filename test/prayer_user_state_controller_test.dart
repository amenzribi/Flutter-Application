import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

Future<void> settle([int ticks = 8]) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeAuthRepository auth;
  late FakeUserStateLocalRepository local;
  late FakeUserStateRemoteRepository remote;
  late ProviderContainer container;

  setUp(() async {
    auth = FakeAuthRepository();
    local = FakeUserStateLocalRepository();
    remote = FakeUserStateRemoteRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userStateLocalRepositoryProvider.overrideWithValue(local),
        userStateRemoteRepositoryProvider.overrideWithValue(remote),
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
  });

  test(
    'togglePrayerCompleted marks then unmarks a prayer, no confirm needed',
    () {
      final notifier = container.read(userStateControllerProvider.notifier);
      final today = DateTime.now();
      String pad(int v) => v.toString().padLeft(2, '0');
      final todayKey = '${today.year}-${pad(today.month)}-${pad(today.day)}';

      notifier.togglePrayerCompleted(PrayerName.fajr);
      var record = container
          .read(userStateControllerProvider)
          .appState
          .prayer
          .recordFor(todayKey);
      expect(record['fajr'], isTrue);

      notifier.togglePrayerCompleted(PrayerName.fajr);
      record = container
          .read(userStateControllerProvider)
          .appState
          .prayer
          .recordFor(todayKey);
      expect(record['fajr'], isFalse);
    },
  );

  test('togglePrayerCompleted accepts a raw legacy key string', () {
    final notifier = container.read(userStateControllerProvider.notifier);
    notifier.togglePrayerCompleted('dhuhr');
    final today = DateTime.now();
    String pad(int v) => v.toString().padLeft(2, '0');
    final todayKey = '${today.year}-${pad(today.month)}-${pad(today.day)}';
    expect(
      container
          .read(userStateControllerProvider)
          .appState
          .prayer
          .recordFor(todayKey)['dhuhr'],
      isTrue,
    );
  });

  test('togglePrayerCompleted is a no-op for an unrecognized key', () async {
    final notifier = container.read(userStateControllerProvider.notifier);
    remote.saveCalls.clear();
    final before = container.read(userStateControllerProvider).appState;

    notifier.togglePrayerCompleted('not-a-prayer');

    expect(container.read(userStateControllerProvider).appState, same(before));
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    expect(remote.saveCalls, isEmpty);
  });

  test('setPrayerCity stores city/country and clears timesDate', () {
    final notifier = container.read(userStateControllerProvider.notifier);
    notifier.applyPrayerSchedule(
      times: const {PrayerName.fajr: '04:00'},
      timesDate: '2026-08-01',
    );
    expect(
      container.read(userStateControllerProvider).appState.prayer.timesDate,
      '2026-08-01',
    );

    notifier.setPrayerCity(city: 'طرابلس', country: 'ليبيا');

    final prayer = container.read(userStateControllerProvider).appState.prayer;
    expect(prayer.city, 'طرابلس');
    expect(prayer.country, 'ليبيا');
    expect(prayer.timesDate, ''); // legacy: forces a refetch
  });

  test(
    'applyPrayerSchedule stores times/timesDate and GPS lat/lng/tz in extra',
    () {
      final notifier = container.read(userStateControllerProvider.notifier);

      notifier.applyPrayerSchedule(
        times: const {
          PrayerName.fajr: '04:12',
          PrayerName.dhuhr: '12:34',
          PrayerName.asr: '16:02',
          PrayerName.maghrib: '19:10',
          PrayerName.isha: '20:35',
        },
        timesDate: '2026-08-04',
        city: 'Tripoli',
        lat: 32.9,
        lng: 13.2,
        tz: 'Africa/Tripoli',
      );

      final prayer = container
          .read(userStateControllerProvider)
          .appState
          .prayer;
      expect(prayer.times['fajr'], '04:12');
      expect(prayer.timesDate, '2026-08-04');
      expect(prayer.city, 'Tripoli');
      // lat/lng/tz sync at the top level of S.prayer via `extra`.
      expect(prayer.extra['lat'], 32.9);
      expect(prayer.extra['lng'], 13.2);
      expect(prayer.extra['tz'], 'Africa/Tripoli');
      expect(prayer.toJson()['lat'], 32.9);
    },
  );

  test(
    'applyPrayerSchedule from a city fetch leaves city/country untouched',
    () {
      final notifier = container.read(userStateControllerProvider.notifier);
      notifier.setPrayerCity(city: 'Benghazi', country: 'Libya');

      notifier.applyPrayerSchedule(
        times: const {PrayerName.fajr: '04:00'},
        timesDate: '2026-08-04',
      );

      final prayer = container
          .read(userStateControllerProvider)
          .appState
          .prayer;
      expect(prayer.city, 'Benghazi');
      expect(prayer.country, 'Libya');
    },
  );
}
