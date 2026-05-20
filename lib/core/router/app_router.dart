// ─────────────────────────────────────────────────────────────
// lib/core/router/app_router.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/media_item.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/media_detail/screens/media_detail_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/shell/screens/shell_screen.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const settings = '/settings';
  static const mediaDetail = '/media-detail';
}

/// Set to true when the user explicitly chooses to browse without signing in.
final guestModeProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthState?>(null);
  final guestNotifier = ValueNotifier<bool>(false);

  ref.listen(authProvider, (_, next) {
    authNotifier.value = next.value;
  });

  ref.listen(guestModeProvider, (_, next) {
    guestNotifier.value = next;
  });

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: Listenable.merge([authNotifier, guestNotifier]),
    redirect: (context, state) {
      final authState = authNotifier.value;
      final isLoading = authState == null;
      final isAuth = authState is AuthStateAuthenticated;
      final isGuest = guestNotifier.value;
      final onAuthPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (isLoading) return null;
      // Already signed in — skip auth screens
      if (isAuth && onAuthPage) return AppRoutes.home;
      // Unauthenticated and not a guest — send to login
      if (!isAuth && !isGuest && !onAuthPage) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const ShellScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.mediaDetail,
        builder: (context, state) =>
            MediaDetailScreen(item: state.extra as MediaItem),
      ),
    ],
  );
});
