import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Owner area shell with bottom navigation.
class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[navigationShell.currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(destination.label)),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
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
