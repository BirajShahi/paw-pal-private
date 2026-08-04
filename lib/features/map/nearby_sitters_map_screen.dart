import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class NearbySittersMapScreen extends StatelessWidget {
  const NearbySittersMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Nearby sitters map',
      message: 'A map of nearby sitters will appear here.',
      showAppBar: false,
    );
  }
}
