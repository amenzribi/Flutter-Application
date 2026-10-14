import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/app/app.dart';
import 'package:barakah40_flutter/app/router/app_router.dart';
import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';
import 'package:barakah40_flutter/features/quran/domain/repositories/quran_text_repository.dart';
import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_controller.dart';
import 'package:barakah40_flutter/features/quran/presentation/providers/quran_providers.dart';
import 'package:barakah40_flutter/features/social/data/firestore_social_repository.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_prayer_location_service.dart';
import 'fakes/fake_prayer_times_repository.dart';
import 'fakes/fake_quran_audio_player.dart';
import 'fakes/fake_user_state_repositories.dart';

class _Surah implements QuranTextRepository {
  @override
  Future<List<Ayah>> loadBaqarah({bool forceRefresh = false}) async => [
    for (var n = 1; n <= 286; n++) Ayah(n: n, text: 'نص الآية الكريمة رقم $n'),
  ];
}

/// Phone widths from the smallest common Android (320) to a large phone.
const _sizes = [Size(320, 568), Size(360, 640), Size(412, 915)];

const _signedInRoutes = [
  AppRoutes.home,
  AppRoutes.challenge,
  AppRoutes.quran,
  AppRoutes.prayer,
  AppRoutes.community,
  '${AppRoutes.community}?tab=1',
  '${AppRoutes.community}?tab=2',
  AppRoutes.tree,
  AppRoutes.adhkar,
  AppRoutes.duas,
  AppRoutes.qibla,
  AppRoutes.settings,
  AppRoutes.journal,
];

const _signedOutRoutes = [
  AppRoutes.welcome,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
];

/// pumpAndSettle that reports a never-ending animation instead of failing.
Future<bool> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    return true;
  } on FlutterError {
    return false;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    // Real fonts, so text is measured as on a phone (the default test font
    // draws every letter as a wide square and exaggerates overflows).
    const fonts = {
      'Tajawal': [
        'assets/fonts/Tajawal-Regular.ttf',
        'assets/fonts/Tajawal-Medium.ttf',
        'assets/fonts/Tajawal-Bold.ttf',
      ],
      'ReemKufi': ['assets/fonts/ReemKufi-Variable.ttf'],
      'Amiri': ['assets/fonts/Amiri-Regular.ttf'],
      'AmiriQuran': ['assets/fonts/AmiriQuran-Regular.ttf'],
    };
    for (final entry in fonts.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        final bytes = File(path).readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });

  Future<List<String>> visitAll(
    WidgetTester tester,
    Size size, {
    required bool signedIn,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The tree scene animates forever unless reduced motion is on.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final auth = FakeAuthRepository(
      initialUser: signedIn
          ? const AppUser(
              uid: 'u1',
              email: 'very.long.address.for.testing@barakah.test',
              displayName: 'اسم طويل جداً لاختبار الشاشات الصغيرة',
              isPasswordUser: true,
            )
          : null,
    );
    addTearDown(auth.dispose);
    final remote = FakeUserStateRemoteRepository();
    addTearDown(remote.dispose);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sharedPreferencesProvider.overrideWithValue(prefs),
        userStateRemoteRepositoryProvider.overrideWithValue(remote),
        socialRepositoryProvider.overrideWithValue(
          FirestoreSocialRepository(firestore: FakeFirebaseFirestore()),
        ),
        quranTextRepositoryProvider.overrideWithValue(_Surah()),
        quranAudioControllerProvider.overrideWith(
          (ref) => QuranAudioController(
            player: FakeQuranAudioPlayer(),
            reciterId: () => 'Alafasy_128kbps',
            onAudioPosChanged: (_) {},
          ),
        ),
        prayerTimesRepositoryProvider.overrideWithValue(
          FakePrayerTimesRepository(
            byCityResult: const PrayerTimesFetchResult(
              times: {
                PrayerName.fajr: '05:40',
                PrayerName.dhuhr: '12:54',
                PrayerName.asr: '16:11',
                PrayerName.maghrib: '18:38',
                PrayerName.isha: '19:58',
              },
            ),
          ),
        ),
        prayerLocationServiceProvider.overrideWithValue(
          FakePrayerLocationService(PrayerLocationResult.permissionDenied()),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BarakahApp(),
      ),
    );
    await tester.pumpAndSettle();

    final problems = <String>[];
    final router = container.read(appRouterProvider);
    for (final route in signedIn ? _signedInRoutes : _signedOutRoutes) {
      router.go(route);
      if (!await _settle(tester)) {
        problems.add('$route @ ${size.width.toInt()}px: never stops loading');
        continue;
      }
      // Scroll each page to the end so lower content is laid out too.
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -3000));
        await _settle(tester);
      }
      final error = tester.takeException();
      if (error != null) {
        problems.add('$route @ ${size.width.toInt()}px: $error');
      }
    }
    // Let debounced saves and countdown timers run out before teardown.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 5));
    return problems;
  }

  for (final size in _sizes) {
    testWidgets('signed-in screens fit at ${size.width.toInt()}px', (
      tester,
    ) async {
      final problems = await visitAll(tester, size, signedIn: true);
      expect(problems, isEmpty);
    });

    testWidgets('sign-in screens fit at ${size.width.toInt()}px', (
      tester,
    ) async {
      final problems = await visitAll(tester, size, signedIn: false);
      expect(problems, isEmpty);
    });
  }
}
