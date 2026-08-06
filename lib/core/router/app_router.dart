import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/account_setup_error_screen.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/auth_role.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/bookings/owner_bookings_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/map/nearby_sitters_map_screen.dart';
import '../../features/owner/owner_dashboard_screen.dart';
import '../../features/owner/owner_shell.dart';
import '../../features/pets/pet_list_screen.dart';
import '../../features/sitter/sitter_dashboard_screen.dart';
import '../../features/sitters/sitter_list_screen.dart';

/// Application route path constants.
abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
  static const owner = '/owner';
  static const pets = '/pets';
  static const sitters = '/sitters';
  static const map = '/map';
  static const bookings = '/bookings';
  static const sitterDashboard = '/sitter-dashboard';
  static const accountSetup = '/account-setup';
}

const _publicRoutes = <String>{
  AppRoutes.home,
  AppRoutes.login,
  AppRoutes.register,
};

const _ownerRoutes = <String>{
  AppRoutes.owner,
  AppRoutes.pets,
  AppRoutes.sitters,
  AppRoutes.map,
  AppRoutes.bookings,
};

const _sitterRoutes = <String>{AppRoutes.sitterDashboard};

/// GoRouter wired to Riverpod auth/role state for redirects.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  ref.listen(authStateProvider, (_, _) {
    refresh.value++;
  });
  ref.listen(currentUserRoleProvider, (_, _) {
    refresh.value++;
  });

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => _authRedirect(ref, state),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountSetup,
        builder: (context, state) => const AccountSetupErrorScreen(),
      ),
      GoRoute(
        path: AppRoutes.sitterDashboard,
        builder: (context, state) => const SitterDashboardScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return OwnerShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.owner,
                builder: (context, state) => const OwnerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pets,
                builder: (context, state) => const PetListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sitters,
                builder: (context, state) => const SitterListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const NearbySittersMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                builder: (context, state) => const OwnerBookingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

String? _authRedirect(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  final authAsync = ref.read(authStateProvider);
  final roleAsync = ref.read(currentUserRoleProvider);
  final hasSession = ref.read(authRepositoryProvider).currentSession != null;

  final isPublic = _publicRoutes.contains(location);
  final isOwnerRoute = _ownerRoutes.contains(location);
  final isSitterRoute = _sitterRoutes.contains(location);
  final isAccountSetup = location == AppRoutes.accountSetup;
  final isProtected = isOwnerRoute || isSitterRoute || isAccountSetup;

  // Avoid flashing protected screens while signed out during initial load.
  if (authAsync.isLoading && !hasSession) {
    if (isProtected) {
      return AppRoutes.login;
    }
    return null;
  }

  if (authAsync.isLoading && hasSession) {
    return null;
  }

  if (authAsync.hasError) {
    if (hasSession) {
      return isAccountSetup ? null : AppRoutes.accountSetup;
    }
    return isProtected ? AppRoutes.login : null;
  }

  final isLoggedIn = hasSession || (authAsync.asData?.value.session != null);

  if (!isLoggedIn) {
    if (isProtected) {
      return AppRoutes.login;
    }
    return null;
  }

  // Signed in: wait for role before deciding.
  if (roleAsync.isLoading) {
    return null;
  }

  if (roleAsync.hasError) {
    return isAccountSetup ? null : AppRoutes.accountSetup;
  }

  final role = roleAsync.asData?.value;
  if (role == null) {
    return isAccountSetup ? null : AppRoutes.accountSetup;
  }

  if (isAccountSetup) {
    return role == AuthRole.owner ? AppRoutes.owner : AppRoutes.sitterDashboard;
  }

  if (isPublic) {
    return role == AuthRole.owner ? AppRoutes.owner : AppRoutes.sitterDashboard;
  }

  if (role == AuthRole.owner && isSitterRoute) {
    return AppRoutes.owner;
  }

  if (role == AuthRole.sitter && isOwnerRoute) {
    return AppRoutes.sitterDashboard;
  }

  return null;
}
