import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/auth_providers.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  bool _isLoggingOut = false;
  String? _errorMessage;

  Future<void> _logOut() async {
    if (_isLoggingOut) return;

    setState(() {
      _errorMessage = null;
      _isLoggingOut = true;
    });

    try {
      await ref.read(authRepositoryProvider).logOut();
      ref.invalidate(currentUserRoleProvider);
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Logout failed. Please try again.';
        _isLoggingOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                      'Owner dashboard',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your owner home overview will appear here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Profile',
                      onPressed: _isLoggingOut
                          ? null
                          : () => context.go(AppRoutes.profile),
                    ),
                    const SizedBox(height: 12),
                    if (_errorMessage != null) ...[
                      ErrorMessage(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    if (_isLoggingOut) ...[
                      const LoadingIndicator(message: 'Signing out…'),
                      const SizedBox(height: 16),
                    ],
                    PrimaryButton(
                      label: 'Log out',
                      isLoading: _isLoggingOut,
                      onPressed: _isLoggingOut ? null : _logOut,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
