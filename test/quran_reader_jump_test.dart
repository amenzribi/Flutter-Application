import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/app/theme/app_theme.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';
import 'package:barakah40_flutter/features/quran/domain/repositories/quran_text_repository.dart';
import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_controller.dart';
import 'package:barakah40_flutter/features/quran/presentation/providers/quran_providers.dart';
import 'package:barakah40_flutter/features/quran/presentation/screens/quran_reader_screen.dart';
import 'package:barakah40_flutter/features/quran/presentation/widgets/ayah_verse_tile.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_quran_audio_player.dart';
import 'fakes/fake_user_state_repositories.dart';

class _FullSurah implements QuranTextRepository {
  @override
  Future<List<Ayah>> loadBaqarah({bool forceRefresh = false}) async => [
    for (var n = 1; n <= 286; n++)
      Ayah(n: n, text: 'نص الآية $n ' * (1 + n % 4)),
  ];
}

void main() {
  testWidgets('jumping to a far verse brings it on screen (phone size)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
          userStateRemoteRepositoryProvider.overrideWithValue(remote),
          quranTextRepositoryProvider.overrideWithValue(_FullSurah()),
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

    bool visible(int n) => find
        .byWidgetPredicate((w) => w is AyahVerseTile && w.ayah.n == n)
        .evaluate()
        .isNotEmpty;
    expect(visible(250), isFalse);

    await tester.enterText(find.byType(TextField), '250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(visible(250), isTrue);

    await tester.enterText(find.byType(TextField), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(visible(3), isTrue);
  });
}
