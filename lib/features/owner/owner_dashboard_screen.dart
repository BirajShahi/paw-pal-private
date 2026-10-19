import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_hero_section.dart';
import '../../core/widgets/dashboard_action_card.dart';
import '../../core/widgets/simple_pet_illustration.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;
    final tablet = width >= 600;

    final actions = [
      (
        Icons.pets_outlined,
        'My Pets',
        'Profiles for personalised care',
        AppRoutes.pets,
      ),
      (
        Icons.search,
        'Find Pet Care',
        'Browse local providers',
        AppRoutes.sitters,
      ),
      (Icons.map_outlined, 'Map', 'See providers nearby', AppRoutes.map),
      (
        Icons.calendar_month_outlined,
        'Bookings',
        'Track requests and history',
        AppRoutes.bookings,
      ),
    ];

    final crossAxisCount = wide ? 4 : 2;
    // Fixed height avoids BOTTOM OVERFLOW on narrow Android widths.
    final mainAxisExtent = wide
        ? 150.0
        : tablet
        ? 148.0
        : width < 360
        ? 142.0
        : 148.0;

    return SafeArea(
      child: SingleChildScrollView(
        child: AppContentContainer(
          maxWidth: AppContentWidth.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppHeroSection(
                title: 'Find the right care for your pet',
                subtitle:
                    'Tell PawPal what your pet needs or explore trusted '
                    'local providers.',
                illustrationKind: PetIllustrationKind.ownerCare,
                tint: AppHeroTint.teal,
                primaryAction: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.aiRecommendation),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Find a Service'),
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: mainAxisExtent,
                ),
                itemBuilder: (context, index) {
                  final item = actions[index];
                  return DashboardActionCard(
                    icon: item.$1,
                    title: item.$2,
                    subtitle: item.$3,
                    onTap: () => context.go(item.$4),
                  );
                },
              ),
              const SizedBox(height: 28),
              _GettingStartedSection(wide: wide, theme: theme, scheme: scheme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GettingStartedSection extends StatelessWidget {
  const _GettingStartedSection({
    required this.wide,
    required this.theme,
    required this.scheme,
  });

  final bool wide;
  final ThemeData theme;
  final ColorScheme scheme;

  static const _checklist = [
    'Keep your pet profile up to date',
    'Describe your pet’s needs clearly',
    'Compare suitable providers before booking',
  ];

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Getting started with PawPal',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A few simple steps can help you find the right care.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
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
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: copy),
                const SizedBox(width: 24),
                const Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SimplePetIllustration(
                      kind: PetIllustrationKind.ownerCare,
                      size: 170,
                    ),
                  ),
                ),
              ],
            )
          : copy,
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
