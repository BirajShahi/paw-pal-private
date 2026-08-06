import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_providers.dart';

/// Shown when the signed-in account is missing a valid profile role.
class AccountSetupErrorScreen extends ConsumerStatefulWidget {
  const AccountSetupErrorScreen({super.key});

  @override
  ConsumerState<AccountSetupErrorScreen> createState() =>
      _AccountSetupErrorScreenState();
}

class _AccountSetupErrorScreenState
    extends ConsumerState<AccountSetupErrorScreen> {
  bool _isLoggingOut = false;
  String? _logoutError;

  Future<void> _logOut() async {
    if (_isLoggingOut) return;

    setState(() {
      _logoutError = null;
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
        _logoutError = 'Logout failed. Please try again.';
        _isLoggingOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(currentUserRoleProvider);
    final authAsync = ref.watch(authStateProvider);

    final message = authAsync.hasError
        ? 'We could not verify your session. Please log out and try again.'
        : roleAsync.hasError
        ? roleAsync.error.toString()
        : 'Your account setup is incomplete. A valid owner or sitter '
              'profile is required.';

    return Scaffold(
      appBar: AppBar(title: const Text('Account setup')),
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
                      ErrorMessage(message: message),
                      if (_logoutError != null) ...[
                        const SizedBox(height: 16),
                        ErrorMessage(message: _logoutError!),
                      ],
                      const SizedBox(height: 24),
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
      ),
    );
  }
}
