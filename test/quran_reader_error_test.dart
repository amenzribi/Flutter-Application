import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/app/theme/app_theme.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/quran/data/sources/quran_api_client.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';
import 'package:barakah40_flutter/features/quran/domain/repositories/quran_text_repository.dart';
import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_controller.dart';
import 'package:barakah40_flutter/features/quran/presentation/providers/quran_providers.dart';
import 'package:barakah40_flutter/features/quran/presentation/screens/quran_reader_screen.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_quran_audio_player.dart';
import 'fakes/fake_user_state_repositories.dart';

/// Always fails, so [baqarahProvider] (an [AsyncNotifier]) surfaces the
/// failure as [AsyncError] instead of ever returning placeholder verses.
class _ThrowingQuranTextRepository implements QuranTextRepository {
  int loadCalls = 0;

  @override
  Future<List<Ayah>> loadBaqarah({bool forceRefresh = false}) {
    loadCalls++;
    throw const QuranTextUnavailableException('network unavailable');
  }
}

void main() {
  Future<_ThrowingQuranTextRepository> pumpErroredReader(
    WidgetTester tester,
  ) async {
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
    final repository = _ThrowingQuranTextRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
          userStateRemoteRepositoryProvider.overrideWithValue(remote),
          quranTextRepositoryProvider.overrideWithValue(repository),
          quranAudioControllerProvider.overrideWith(
            (ref) => QuranAudioController(
              player: FakeQuranAudioPlayer(),
              reciterId: () => 'Alafasy_128kbps',
              onAudioPosChanged: (_) {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: QuranReaderScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('shows an Arabic error with retry when baqarahProvider fails', (
    tester,
  ) async {
    await pumpErroredReader(tester);

    expect(find.text('تعذّر تحميل سورة البقرة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    // Never falls back to fake/placeholder ayah content.
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('retry re-invokes the repository instead of faking content', (
    tester,
  ) async {
    final repository = await pumpErroredReader(tester);
    final callsBeforeRetry = repository.loadCalls;

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, greaterThan(callsBeforeRetry));
    expect(find.text('تعذّر تحميل سورة البقرة'), findsOneWidget);
  });
}
