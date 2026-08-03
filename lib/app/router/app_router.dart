import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/splash_screen.dart';
import 'package:barakah40_flutter/features/auth/presentation/screens/welcome_screen.dart';
import 'package:barakah40_flutter/features/home/presentation/screens/home_dashboard_screen.dart';

/// Listenable that notifies GoRouter when auth state changes.
class GoRouterAuthRefresh extends ChangeNotifier {
  GoRouterAuthRefresh(Ref ref) {
    _subscription = ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AppUser?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final goRouterAuthRefreshProvider = Provider<GoRouterAuthRefresh>((ref) {
  final refresh = GoRouterAuthRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

/// Resolves redirects for splash / public / authenticated routes.
String? resolveAuthRedirect({
  required AsyncValue<AppUser?> authState,
  required String location,
}) {
  final loggingIn = AppRoutes.publicLocations.contains(location);
  final isSplash = location == AppRoutes.splash;

  if (authState.isLoading || authState.isRefreshing) {
    return isSplash ? null : AppRoutes.splash;
  }

  if (authState.hasError) {
    return loggingIn && !isSplash ? null : AppRoutes.welcome;
  }

  final user = authState.valueOrNull;
  final signedIn = user != null;

  if (isSplash) {
    return signedIn ? AppRoutes.home : AppRoutes.welcome;
  }

  if (!signedIn && !loggingIn) {
    return AppRoutes.welcome;
  }

  if (signedIn && loggingIn) {
    return AppRoutes.home;
  }

  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterAuthRefreshProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      return resolveAuthRedirect(
        authState: authState,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: AppRoutes.welcomeName,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomeDashboardScreen(),
      ),
    ],
  );
});
