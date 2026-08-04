import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/primary_button.dart';

/// Temporary home screen with navigation entry points.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PawPal')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome to PawPal',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connecting pet owners with trusted sitters.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      PrimaryButton(
                        label: 'Login',
                        onPressed: () => context.go(AppRoutes.login),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Registration',
                        onPressed: () => context.go(AppRoutes.register),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Owner dashboard',
                        onPressed: () => context.go(AppRoutes.owner),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Sitter dashboard',
                        onPressed: () => context.go(AppRoutes.sitterDashboard),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
