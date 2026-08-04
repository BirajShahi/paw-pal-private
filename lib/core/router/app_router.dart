import 'package:go_router/go_router.dart';

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
}

/// GoRouter configuration for PawPal navigation.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
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
