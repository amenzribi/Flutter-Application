import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/router/app_router.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';

import 'fakes/fake_auth_repository.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('keeps splash while loading', () {
      expect(
        resolveAuthRedirect(
          authState: const AsyncLoading<AppUser?>(),
          location: AppRoutes.splash,
        ),
        isNull,
      );
    });

    test('sends non-splash routes to splash while loading', () {
      expect(
        resolveAuthRedirect(
          authState: const AsyncLoading<AppUser?>(),
          location: AppRoutes.login,
        ),
        AppRoutes.splash,
      );
    });

    test('splash → welcome when signed out', () {
      expect(
        resolveAuthRedirect(
          authState: const AsyncData<AppUser?>(null),
          location: AppRoutes.splash,
        ),
        AppRoutes.welcome,
      );
    });

    test('splash → home when signed in', () {
      expect(
        resolveAuthRedirect(
          authState: const AsyncData<AppUser?>(
            AppUser(uid: '1', email: 'a@b.co'),
          ),
          location: AppRoutes.splash,
        ),
        AppRoutes.home,
      );
    });

    test('blocks home when signed out', () {
      expect(
        resolveAuthRedirect(
          authState: const AsyncData<AppUser?>(null),
          location: AppRoutes.home,
        ),
        AppRoutes.welcome,
      );
    });

    test('blocks public auth pages when signed in', () {
      expect(
        resolveAuthRedirect(
          authState: const AsyncData<AppUser?>(
            AppUser(uid: '1', email: 'a@b.co'),
          ),
          location: AppRoutes.login,
        ),
        AppRoutes.home,
      );
    });
  });

  group('AuthController', () {
    late FakeAuthRepository fake;
    late ProviderContainer container;

    setUp(() {
      fake = FakeAuthRepository();
      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(() {
        fake.dispose();
        container.dispose();
      });
    });

    test('rejects invalid registration before repository call', () async {
      final controller = container.read(authControllerProvider.notifier);
      final ok = await controller.register(
        name: 'أ',
        email: 'bad',
        password: '1',
      );
      expect(ok, isFalse);
      expect(fake.registerCalls, 0);
      expect(
        container.read(authControllerProvider).status,
        AuthFormStatus.error,
      );
    });

    test('register success transitions to success and emits user', () async {
      final controller = container.read(authControllerProvider.notifier);
      final ok = await controller.register(
        name: 'نورة',
        email: 'noura@email.com',
        password: '123456',
      );
      expect(ok, isTrue);
      expect(fake.registerCalls, 1);
      expect(fake.currentUser?.email, 'noura@email.com');
      expect(
        container.read(authControllerProvider).status,
        AuthFormStatus.success,
      );
    });

    test('login validation and success', () async {
      final controller = container.read(authControllerProvider.notifier);
      expect(await controller.login(email: 'bad', password: '123456'), isFalse);
      expect(fake.loginCalls, 0);

      expect(
        await controller.login(email: 'a@b.co', password: '123456'),
        isTrue,
      );
      expect(fake.loginCalls, 1);
    });

    test('password reset validation and success message', () async {
      final controller = container.read(authControllerProvider.notifier);
      expect(await controller.resetPassword(email: ''), isFalse);
      expect(fake.resetCalls, 0);

      expect(await controller.resetPassword(email: 'a@b.co'), isTrue);
      expect(fake.resetCalls, 1);
      expect(
        container.read(authControllerProvider).message,
        'أرسلنا رابط إعادة التعيين',
      );
    });

    test('maps repository errors without credentials', () async {
      fake.failNext = true;
      fake.nextError = Exception('secret-token-should-not-leak');
      final controller = container.read(authControllerProvider.notifier);
      final ok = await controller.login(email: 'a@b.co', password: '123456');
      expect(ok, isFalse);
      final message = container.read(authControllerProvider).message ?? '';
      expect(message.contains('secret-token'), isFalse);
      expect(message, 'تعذّر إتمام العملية');
    });

    test('logout clears session', () async {
      fake.emit(const AppUser(uid: '1', email: 'a@b.co'));
      final controller = container.read(authControllerProvider.notifier);
      await controller.logout();
      expect(fake.logoutCalls, 1);
      expect(fake.currentUser, isNull);
    });
  });
}
