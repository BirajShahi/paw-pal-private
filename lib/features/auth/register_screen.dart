import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Registration',
      message: 'Account registration will be available in a later ticket.',
    );
  }
}
