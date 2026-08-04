import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Login',
      message: 'Sign in will be available in a later ticket.',
    );
  }
}
