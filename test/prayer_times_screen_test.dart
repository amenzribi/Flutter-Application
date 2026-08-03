import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/app/theme/app_theme.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:barakah40_flutter/features/prayer/presentation/screens/prayer_times_screen.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_prayer_location_service.dart';
import 'fakes/fake_prayer_times_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<void> pumpPrayerScreen(
    WidgetTester tester, {
    FakeUserStateLocalRepository? local,
    required FakePrayerLocationService locationService,
    FakePrayerTimesRepository? timesRepository,
    // `false` for scenarios that resolve to a ready schedule: `ready`
    // mounts NextPrayerCard, which runs a `Timer.periodic` countdown that
    // never lets `pumpAndSettle` reach a steady state.
    bool settle = true,
  }) async {
    final auth = FakeAuthRepository(
      initialUser: const AppUser(
        uid: 'u1',
        email: 'a@b.co',
        emailVerified: true,
      ),
    );
    addTearDown(auth.dispose);
    final remote = FakeUserStateRemoteRepository();
    addTearDown(remote.dispose);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Unmounts the tree at teardown so NextPrayerCard's countdown Timer (if
    // any was started for a `ready` schedule) is cancelled via `dispose()`
    // before the test's FakeAsync zone is checked for pending timers.
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
          userStateRemoteRepositoryProvider.overrideWithValue(remote),
          if (local != null)
            userStateLocalRepositoryProvider.overrideWithValue(local),
          prayerLocationServiceProvider.overrideWithValue(locationService),
          prayerTimesRepositoryProvider.overrideWithValue(
            timesRepository ?? FakePrayerTimesRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: PrayerTimesScreen(),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Let the async fetch pipeline (repository/location futures) resolve
      // without waiting for the next-prayer countdown timer to settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }
  }

  testWidgets(
    'shows needsCity with a button to add a city when there is no city '
    'and the silent GPS attempt fails generically',
    (tester) async {
      await pumpPrayerScreen(
        tester,
        locationService: FakePrayerLocationService(
          PrayerLocationResult.serviceDisabled(),
        ),
      );

      expect(
        find.textContaining('لم تُحدَّد مدينة لأوقات الصلاة بعد'),
        findsOneWidget,
      );
      expect(find.text('تحديد المدينة'), findsOneWidget);
      // Never shows an invented schedule.
      expect(find.byType(Checkbox), findsNothing);
    },
  );

  testWidgets(
    'shows a permission-denied explanation with a manual-city fallback',
    (tester) async {
      await pumpPrayerScreen(
        tester,
        locationService: FakePrayerLocationService(
          PrayerLocationResult.permissionDenied(),
        ),
      );

      expect(
        find.textContaining(PrayerLocationCopy.permissionDeniedExplanation),
        findsOneWidget,
      );
      expect(find.text('إدخال المدينة يدويًا'), findsOneWidget);
    },
  );

  testWidgets('shows a retry-able error when the city fetch fails', (
    tester,
  ) async {
    final local = FakeUserStateLocalRepository();
    local.seed(
      'u1',
      UserAppState.defaults().copyWith(
        prayer: const PrayerSettings().copyWith(
          city: 'Tripoli',
          country: 'Libya',
        ),
      ),
    );

    await pumpPrayerScreen(
      tester,
      local: local,
      locationService: FakePrayerLocationService(
        PrayerLocationResult.permissionDenied(),
      ),
      timesRepository: FakePrayerTimesRepository(throwsError: true),
    );

    expect(find.textContaining('تعذّر جلب أوقات الصلاة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('renders the five prayers with real fetched times once ready', (
    tester,
  ) async {
    final local = FakeUserStateLocalRepository();
    local.seed(
      'u1',
      UserAppState.defaults().copyWith(
        prayer: const PrayerSettings().copyWith(
          city: 'Tripoli',
          country: 'Libya',
        ),
      ),
    );

    await pumpPrayerScreen(
      tester,
      local: local,
      locationService: FakePrayerLocationService(
        PrayerLocationResult.permissionDenied(),
      ),
      timesRepository: FakePrayerTimesRepository(
        byCityResult: const PrayerTimesFetchResult(
          times: {
            PrayerName.fajr: '04:12',
            PrayerName.dhuhr: '12:34',
            PrayerName.asr: '16:02',
            PrayerName.maghrib: '19:10',
            PrayerName.isha: '20:35',
          },
        ),
      ),
      settle: false,
    );

    for (final name in PrayerName.values) {
      expect(find.text(name.arabicLabel), findsOneWidget);
    }
    expect(find.text('04:12'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(5));
    // Never invents a time that wasn't actually fetched.
    expect(find.text('--:--'), findsNothing);
  });

  testWidgets('toggling a prayer checkbox calls the tracking mutator', (
    tester,
  ) async {
    final local = FakeUserStateLocalRepository();
    local.seed(
      'u1',
      UserAppState.defaults().copyWith(
        prayer: const PrayerSettings().copyWith(
          city: 'Tripoli',
          country: 'Libya',
        ),
      ),
    );

    await pumpPrayerScreen(
      tester,
      local: local,
      locationService: FakePrayerLocationService(
        PrayerLocationResult.permissionDenied(),
      ),
      timesRepository: FakePrayerTimesRepository(
        byCityResult: const PrayerTimesFetchResult(
          times: {
            PrayerName.fajr: '04:12',
            PrayerName.dhuhr: '12:34',
            PrayerName.asr: '16:02',
            PrayerName.maghrib: '19:10',
            PrayerName.isha: '20:35',
          },
        ),
      ),
      settle: false,
    );

    expect(find.text('0 / 5'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('root layout is RTL', (tester) async {
    await pumpPrayerScreen(
      tester,
      locationService: FakePrayerLocationService(
        PrayerLocationResult.serviceDisabled(),
      ),
    );

    final element = tester.element(find.byType(PrayerTimesScreen));
    expect(Directionality.of(element), TextDirection.rtl);
  });
}
