import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class SitterListScreen extends StatelessWidget {
  const SitterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Sitters',
      message: 'Available sitters will be listed here.',
      showAppBar: false,
    );
  }
}
