import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class OwnerBookingsScreen extends StatelessWidget {
  const OwnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Bookings',
      message: 'Your bookings will appear here.',
      showAppBar: false,
    );
  }
}
