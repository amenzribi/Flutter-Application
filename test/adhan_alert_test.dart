import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';
import 'package:barakah40_flutter/features/prayer/data/notifications/adhan_notifier.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/adhan_alert_provider.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/reminder_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_prayer_location_service.dart';
import 'fakes/fake_prayer_times_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

class _FakeNotifier implements AdhanNotifier {
  final shown = <String>[];

  @override
  bool get supported => true;

  @override
  bool get granted => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  void show({required String title, required String body}) => shown.add(title);
}

Future<void> settle([int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final today = DateTime.now();
  DateTime at(int h, int m, [int s = 0, int ms = 0]) =>
      DateTime(today.year, today.month, today.day, h, m, s, ms);

  late ProviderContainer container;
  late _FakeNotifier notifier;
  late DateTime now;

  Future<void> start({bool enabled = true, String city = 'Tunis'}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();
    final remote = FakeUserStateRemoteRepository();
    final local = FakeUserStateLocalRepository()
      ..seed(
        'u1',
        UserAppState.defaults().copyWith(
          reminder: ReminderSettings(enabled: enabled, prayer: true),
          prayer: PrayerSettings(
            city: city,
            timesDate: PrayerDayKey.dayKey(today),
            times: const {
              'fajr': '05:40',
              'dhuhr': '12:54',
              'asr': '16:11',
              'maghrib': '18:38',
              'isha': '19:58',
            },
          ),
        ),
      );
    notifier = _FakeNotifier();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sharedPreferencesProvider.overrideWithValue(prefs),
        userStateLocalRepositoryProvider.overrideWithValue(local),
        userStateRemoteRepositoryProvider.overrideWithValue(remote),
        prayerTimesRepositoryProvider.overrideWithValue(
          FakePrayerTimesRepository(
            byCityResult: const PrayerTimesFetchResult(times: {}),
          ),
        ),
        prayerLocationServiceProvider.overrideWithValue(
          FakePrayerLocationService(PrayerLocationResult.permissionDenied()),
        ),
        adhanNotifierProvider.overrideWithValue(notifier),
        adhanClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(() {
      container.dispose();
      auth.dispose();
      remote.dispose();
    });
    container.read(userStateControllerProvider.notifier);
    auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
    await settle();
  }

  test('waits for the next prayer of the day', () async {
    now = at(13, 0);
    await start();
    final plan = container.read(adhanAlertProvider)!;
    expect(plan.prayer, PrayerName.asr);
    expect(plan.wakeAt, at(16, 11));
  });

  test('after Isha it wakes after midnight to load the new times', () async {
    now = at(21, 0);
    await start();
    final plan = container.read(adhanAlertProvider)!;
    expect(plan.prayer, isNull);
    expect(plan.wakeAt, DateTime(today.year, today.month, today.day + 1, 0, 1));
  });

  test(
    'announces the prayer when its time comes, then waits for the next',
    () async {
      now = at(12, 53, 59, 900);
      await start();
      final sub = container.listen(adhanAlertProvider, (_, _) {});
      addTearDown(sub.close);
      expect(sub.read()!.prayer, PrayerName.dhuhr);
      now = at(12, 54, 1);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(notifier.shown, ['حان الآن موعد أذان الظهر']);
      expect(sub.read()!.prayer, PrayerName.asr);
    },
  );

  test('off when the switch is off', () async {
    now = at(13, 0);
    await start(enabled: false);
    expect(container.read(adhanAlertProvider), isNull);
  });

  test('never asks for GPS when no place is saved', () async {
    now = at(13, 0);
    await start(city: '');
    expect(container.read(adhanAlertProvider), isNull);
  });
}
