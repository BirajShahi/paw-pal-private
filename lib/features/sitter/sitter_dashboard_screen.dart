import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_hero_section.dart';
import '../../core/widgets/dashboard_action_card.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/pawpal_app_bar.dart';
import '../../core/widgets/simple_pet_illustration.dart';
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tablet = MediaQuery.sizeOf(context).width >= 700;

    final actions = [
      (
        Icons.person_outline,
        'Profile',
        'Keep suburb, rates and description up to date.',
        AppRoutes.sitterProfile,
      ),
      (
        Icons.handyman_outlined,
        'Manage Services',
        'Choose services, prices and availability.',
        AppRoutes.sitterServices,
      ),
    ];

    return Scaffold(
      appBar: PawPalAppBar(
        title: 'Sitter dashboard',
        actions: [
          if (wide)
            TextButton.icon(
              onPressed: _isLoggingOut
                  ? null
                  : () => context.push(AppRoutes.sitterProfile),
              icon: const Icon(Icons.person_outline, size: 20),
              label: const Text('Profile'),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoggingOut ? null : _logOut,
              child: _isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log out'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AppContentContainer(
            maxWidth: AppContentWidth.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppHeroSection(
                  title: 'Manage your PawPal services',
                  subtitle:
                      'Keep your profile updated, manage your services and '
                      'respond to booking requests.',
                  illustrationKind: PetIllustrationKind.sitterWithPet,
                  tint: AppHeroTint.coral,
                  primaryAction: FilledButton.icon(
                    onPressed: _isLoggingOut
                        ? null
                        : () => context.push(AppRoutes.sitterBookings),
                    icon: const Icon(Icons.inbox_outlined, size: 18),
                    label: const Text('View Booking Requests'),
                  ),
                  secondaryAction: OutlinedButton(
                    onPressed: _isLoggingOut
                        ? null
                        : () => context.push(AppRoutes.sitterServices),
                    child: const Text('Manage Services'),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Quick actions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 14),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 14),
                        Expanded(
                          child: DashboardActionCard(
                            icon: actions[i].$1,
                            title: actions[i].$2,
                            subtitle: actions[i].$3,
                            enabled: !_isLoggingOut,
                            onTap: () => context.push(actions[i].$4),
                          ),
                        ),
                      ],
                    ],
                  )
                else if (tablet)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      for (final action in actions)
                        DashboardActionCard(
                          icon: action.$1,
                          title: action.$2,
                          subtitle: action.$3,
                          enabled: !_isLoggingOut,
                          onTap: () => context.push(action.$4),
                        ),
                    ],
                  )
                else
                  Column(
                    children: [
                      for (final action in actions) ...[
                        DashboardActionCard(
                          icon: action.$1,
                          title: action.$2,
                          subtitle: action.$3,
                          enabled: !_isLoggingOut,
                          compact: true,
                          onTap: () => context.push(action.$4),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 28),
                _ProfileReadySection(wide: wide, theme: theme, scheme: scheme),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  ErrorMessage(message: _errorMessage!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileReadySection extends StatelessWidget {
  const _ProfileReadySection({
    required this.wide,
    required this.theme,
    required this.scheme,
  });

  final bool wide;
  final ThemeData theme;
  final ColorScheme scheme;

  static const _checklist = [
    'Keep your service description current',
    'Make sure your active services and prices are accurate',
    'Review new booking requests regularly',
  ];

  @override
  Widget build(BuildContext context) {
    final checklist = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keep your PawPal profile ready',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A clear, up-to-date profile helps owners choose you with confidence.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        for (final item in _checklist) ...[
          _ChecklistItem(label: item),
          const SizedBox(height: 12),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 28 : 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: checklist),
                const SizedBox(width: 24),
                const Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SimplePetIllustration(
                      kind: PetIllustrationKind.sitterWithPet,
                      size: 180,
                    ),
                  ),
                ),
              ],
            )
          : checklist,
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 20, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}
