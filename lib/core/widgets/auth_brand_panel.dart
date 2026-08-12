import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'simple_pet_illustration.dart';

/// Branded left panel for Login / Register on desktop.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({
    super.key,
    required this.headline,
    required this.supportingText,
    required this.benefits,
    this.compact = false,
    this.illustrationKind = PetIllustrationKind.ownerWithPet,
  });

  final String headline;
  final String supportingText;
  final List<(IconData, String)> benefits;
  final bool compact;
  final PetIllustrationKind illustrationKind;

  static const _logoAsset = 'assets/branding/pawpal_icon.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (compact) {
      return Column(
        children: [
          Image.asset(
            _logoAsset,
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: 10),
          Text(
            'PawPal',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          SimplePetIllustration(kind: illustrationKind, size: 120),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Image.asset(
                _logoAsset,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 12),
              Text(
                'PawPal',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            headline,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 28,
              height: 1.25,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            supportingText,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: SimplePetIllustration(kind: illustrationKind, size: 200),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < benefits.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _BenefitRow(icon: benefits[i].$1, label: benefits[i].$2),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
