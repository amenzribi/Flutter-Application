import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/app/app.dart';
import 'package:barakah40_flutter/app/theme/app_theme.dart';
import 'package:barakah40_flutter/core/constants/app_constants.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/welcome_screen.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_fields.dart';
import 'package:go_router/go_router.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });
  testWidgets('signed-out app lands on welcome after splash', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const BarakahApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('إنشاء حساب'), findsOneWidget);
    expect(find.textContaining('البقرة'), findsOneWidget);
  });

  testWidgets('welcome actions navigate to login and register', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);

    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('login-page')),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) =>
              const Scaffold(body: Text('register-page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('login-page'), findsOneWidget);

    router.go('/welcome');
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();
    expect(find.text('register-page'), findsOneWidget);
  });

  testWidgets('login validation shows Arabic error without calling repo', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.textContaining('بريد'), findsWidgets);
    expect(fake.loginCalls, 0);
  });

  testWidgets('registration validation requires name', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: RegisterScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'noura@email.com');
    await tester.enterText(find.byType(TextField).at(2), '123456');
    await tester.tap(find.text('إنشاء الحساب'));
    await tester.pumpAndSettle();

    expect(find.textContaining('اسمك'), findsOneWidget);
    expect(fake.registerCalls, 0);
  });

  testWidgets('loading button disables while busy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: LoadingButton(label: 'حفظ', busy: true, onPressed: null),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error banner displays message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ErrorBanner(message: 'خطأ تجريبي')),
      ),
    );
    expect(find.text('خطأ تجريبي'), findsOneWidget);
  });

  testWidgets('RTL directionality on welcome', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const BarakahApp(),
      ),
    );
    await tester.pumpAndSettle();

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('light and dark theme smoke', (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: Text(AppConstants.appName)),
        ),
      );
      expect(find.text(AppConstants.appName), findsOneWidget);
    }
  });

  testWidgets('responsive welcome at mobile and desktop widths', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);

    Future<void> pumpWidth(double width) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fake)],
          child: const BarakahApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    await pumpWidth(390);
    await pumpWidth(1280);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('authenticated home shows dashboard empty states and logout', (
    tester,
  ) async {
    final fake = FakeAuthRepository(
      initialUser: const AppUser(
        uid: 'u1',
        email: 'user@example.com',
        displayName: 'نورة',
      ),
    );
    addTearDown(fake.dispose);
    final fakeRemote = FakeUserStateRemoteRepository();
    addTearDown(fakeRemote.dispose);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fake),
          sharedPreferencesProvider.overrideWithValue(prefs),
          userStateRemoteRepositoryProvider.overrideWithValue(fakeRemote),
        ],
        child: const BarakahApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('نورة'), findsWidgets);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('سلسلة المواظبة'), findsOneWidget);
    expect(find.text('تحدّي الأربعين'), findsOneWidget);
    expect(find.text('تقدّم القرآن'), findsOneWidget);
    expect(find.text('شجرة البركة'), findsOneWidget);
    expect(find.text('الأذكار'), findsWidgets);
    expect(find.textContaining('لم يبدأ'), findsWidgets);
    expect(find.byTooltip('تسجيل الخروج'), findsOneWidget);

    await tester.tap(find.byTooltip('تسجيل الخروج'));
    await tester.pumpAndSettle();

    expect(fake.logoutCalls, 1);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
