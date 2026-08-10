import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/error_message.dart';
import '../auth/auth_providers.dart';

class SitterDashboardScreen extends ConsumerStatefulWidget {
  const SitterDashboardScreen({super.key});

  @override
  ConsumerState<SitterDashboardScreen> createState() =>
      _SitterDashboardScreenState();
}

class _SitterDashboardScreenState extends ConsumerState<SitterDashboardScreen> {
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final actions = [
      (
        Icons.person_outline,
        'Profile',
        'Keep your suburb, rates and description up to date.',
        AppRoutes.sitterProfile,
      ),
      (
        Icons.handyman_outlined,
        'Manage Services',
        'Choose services, prices and availability status.',
        AppRoutes.sitterServices,
      ),
      (
        Icons.inbox_outlined,
        'Booking Requests',
        'Accept and manage owner booking requests.',
        AppRoutes.sitterBookings,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sitter dashboard')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              child: AppContentContainer(
                maxWidth: AppContentWidth.page,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.secondaryContainer.withValues(alpha: 0.65),
                            AppColors.surfaceTint,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage your PawPal services',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Update your profile, offerings, and respond to '
                            'booking requests.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: _SitterActionCard(
                                icon: actions[i].$1,
                                title: actions[i].$2,
                                subtitle: actions[i].$3,
                                enabled: !_isLoggingOut,
                                onTap: () => context.go(actions[i].$4),
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Column(
                        children: [
                          for (final action in actions) ...[
                            _SitterActionCard(
                              icon: action.$1,
                              title: action.$2,
                              subtitle: action.$3,
                              enabled: !_isLoggingOut,
                              onTap: () => context.go(action.$4),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (_errorMessage != null) ...[
                      ErrorMessage(message: _errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      onPressed: _isLoggingOut ? null : _logOut,
                      child: _isLoggingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Log out'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SitterActionCard extends StatelessWidget {
  const _SitterActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
