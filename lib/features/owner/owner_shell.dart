import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Owner area shell with bottom navigation.
class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_OwnerDestination>[
    _OwnerDestination(label: 'Home', icon: Icons.home_outlined),
    _OwnerDestination(label: 'Pets', icon: Icons.pets_outlined),
    _OwnerDestination(label: 'Sitters', icon: Icons.people_outline),
    _OwnerDestination(label: 'Map', icon: Icons.map_outlined),
    _OwnerDestination(label: 'Bookings', icon: Icons.calendar_month_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[navigationShell.currentIndex].label),
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _OwnerDestination {
  const _OwnerDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
