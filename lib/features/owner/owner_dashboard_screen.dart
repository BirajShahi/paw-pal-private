import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Owner dashboard',
      message: 'Your owner home overview will appear here.',
      showAppBar: false,
    );
  }
}
