import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/app/theme/app_theme.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/quran/presentation/screens/challenge_overview_screen.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

void main() {
  Future<void> pumpChallengeScreen(
    WidgetTester tester, {
    FakeUserStateLocalRepository? local,
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
          userStateRemoteRepositoryProvider.overrideWithValue(remote),
          if (local != null)
            userStateLocalRepositoryProvider.overrideWithValue(local),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: ChallengeOverviewScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('explains manual completion without an assigned ayah range', (
    tester,
  ) async {
    await pumpChallengeScreen(tester);

    expect(find.text('كيف يعمل التحدّي؟'), findsOneWidget);
    expect(find.textContaining('اقرئي سورة البقرة كاملةً'), findsOneWidget);
    expect(find.textContaining('لا يوجد تقسيم'), findsOneWidget);
    // Never mentions an assigned/automatic daily verse range.
    expect(find.textContaining('آية اليوم'), findsNothing);
  });

  testWidgets('renders exactly 40 day cells in the grid', (tester) async {
    await pumpChallengeScreen(tester);

    final dayNumbers = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Text),
    );
    expect(dayNumbers, findsNWidgets(40));
  });

  testWidgets('shows the empty state before the challenge has started', (
    tester,
  ) async {
    await pumpChallengeScreen(tester);

    expect(find.text('لم يبدأ تحدّيك بعد'), findsOneWidget);
  });

  testWidgets('shows completed/total days once the challenge has started', (
    tester,
  ) async {
    final local = FakeUserStateLocalRepository();
    local.seed(
      'u1',
      UserAppState.defaults().copyWith(
        started: 1000,
        completed: List<bool>.filled(40, false)
          ..[0] = true
          ..[1] = true,
      ),
    );
    await pumpChallengeScreen(tester, local: local);

    expect(find.text('2 من 40 يوماً مكتملة'), findsOneWidget);
    expect(find.text('اليوم الحالي: 3'), findsOneWidget);
  });

  testWidgets('root layout is RTL', (tester) async {
    await pumpChallengeScreen(tester);

    final element = tester.element(find.byType(ChallengeOverviewScreen));
    expect(Directionality.of(element), TextDirection.rtl);
  });
}
