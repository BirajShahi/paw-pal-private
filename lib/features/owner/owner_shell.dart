import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/pawpal_app_bar.dart';
import '../auth/auth_providers.dart';

/// Owner area shell with bottom navigation.
class OwnerShell extends ConsumerStatefulWidget {
  const OwnerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  bool _isLoggingOut = false;

  static const _destinations = <_OwnerDestination>[
    _OwnerDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _OwnerDestination(
      label: 'Pets',
      icon: Icons.pets_outlined,
      selectedIcon: Icons.pets,
    ),
    _OwnerDestination(
      label: 'Sitters',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    _OwnerDestination(
      label: 'Map',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
    ),
    _OwnerDestination(
      label: 'Bookings',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
  ];

  Future<void> _logOut() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      await ref.read(authRepositoryProvider).logOut();
      ref.invalidate(currentUserRoleProvider);
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[widget.navigationShell.currentIndex];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: PawPalAppBar(
        title: destination.label == 'Home'
            ? 'Owner dashboard'
            : destination.label,
        actions: [
          if (wide)
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.profile),
              icon: const Icon(Icons.person_outline, size: 20),
              label: const Text('Profile'),
            )
          else
            IconButton(
              tooltip: 'Profile',
              onPressed: () => context.push(AppRoutes.profile),
              icon: const Icon(Icons.person_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: wide
                ? TextButton(
                    onPressed: _isLoggingOut ? null : _logOut,
                    child: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log out'),
                  )
                : IconButton(
                    tooltip: 'Log out',
                    onPressed: _isLoggingOut ? null : _logOut,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                  ),
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: widget.navigationShell.goBranch,
        destinations: [
          for (final item in _destinations)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _OwnerDestination {
  const _OwnerDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
