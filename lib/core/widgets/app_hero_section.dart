import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'simple_pet_illustration.dart';

/// Dashboard hero with copy, actions, and a flat illustration.
class AppHeroSection extends StatelessWidget {
  const AppHeroSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.illustrationKind,
    this.primaryAction,
    this.secondaryAction,
    this.tint = AppHeroTint.teal,
  });

  final String title;
  final String subtitle;
  final PetIllustrationKind illustrationKind;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final AppHeroTint tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1000;
    final compact = width < 600;

    final gradientColors = switch (tint) {
      AppHeroTint.teal => [
        scheme.primaryContainer.withValues(alpha: 0.7),
        AppColors.surfaceTint,
      ],
      AppHeroTint.coral => [
        scheme.secondaryContainer.withValues(alpha: 0.55),
        AppColors.surfaceTint,
      ],
    };

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: desktop
                ? 30
                : compact
                ? 22
                : 26,
            height: 1.25,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
            fontSize: desktop
                ? 16
                : compact
                ? 14
                : 15,
          ),
        ),
        if (primaryAction != null || secondaryAction != null) ...[
          SizedBox(height: compact ? 14 : 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [?primaryAction, ?secondaryAction],
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: desktop
            ? 28
            : compact
            ? 16
            : 20,
        vertical: desktop
            ? 28
            : compact
            ? 16
            : 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: textColumn),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SimplePetIllustration(
                      kind: illustrationKind,
                      size: 200,
                    ),
                  ),
                ),
              ],
            )
          : compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                textColumn,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: SimplePetIllustration(
                    kind: illustrationKind,
                    size: 96,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: textColumn),
                const SizedBox(width: 12),
                SimplePetIllustration(kind: illustrationKind, size: 120),
              ],
            ),
    );
  }
}

enum AppHeroTint { teal, coral }
