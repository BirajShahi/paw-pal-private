import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class PetListScreen extends StatelessWidget {
  const PetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Pets',
      message: 'Your pets will be listed here.',
      showAppBar: false,
    );
  }
}
