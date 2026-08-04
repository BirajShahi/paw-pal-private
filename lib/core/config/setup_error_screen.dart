import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/error_message.dart';

/// Shown when Supabase dart-define values are missing.
class SetupErrorApp extends StatelessWidget {
  const SetupErrorApp({super.key});

  static const _message =
      'Supabase is not configured. Provide SUPABASE_URL and '
      'SUPABASE_PUBLISHABLE_KEY using --dart-define when running the app.';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawPal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SetupErrorScreen(),
    );
  }
}

class SetupErrorScreen extends StatelessWidget {
  const SetupErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PawPal setup')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 24.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: const ErrorMessage(message: SetupErrorApp._message),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
