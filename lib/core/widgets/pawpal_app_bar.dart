import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Compact application header with PawPal mark, title, and optional actions.
class PawPalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PawPalAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return AppBar(
      automaticallyImplyLeading: showBack,
      titleSpacing: wide ? 20 : 8,
      title: Row(
        children: [
          Icon(Icons.pets, size: 22, color: theme.colorScheme.primary),
          if (wide) ...[
            const SizedBox(width: 8),
            Text(
              'PawPal',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              width: 1,
              height: 18,
              color: AppColors.outlineVariant,
            ),
          ] else
            const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}
