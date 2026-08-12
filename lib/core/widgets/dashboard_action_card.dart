import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Quick-action card used on owner and sitter dashboards.
class DashboardActionCard extends StatefulWidget {
  const DashboardActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool compact;

  @override
  State<DashboardActionCard> createState() => _DashboardActionCardState();
}

class _DashboardActionCardState extends State<DashboardActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final padding = widget.compact
        ? 16.0
        : narrow
        ? 14.0
        : 20.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered && widget.enabled
                ? scheme.primary.withValues(alpha: 0.35)
                : AppColors.outlineVariant.withValues(alpha: 0.55),
          ),
          boxShadow: _hovered && widget.enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.enabled ? widget.onTap : null,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: widget.compact
                  ? _CompactBody(
                      icon: widget.icon,
                      title: widget.title,
                      subtitle: widget.subtitle,
                    )
                  : _ExpandedBody(
                      icon: widget.icon,
                      title: widget.title,
                      subtitle: widget.subtitle,
                      dense: narrow,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dense,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconSize = dense ? 40.0 : 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary, size: dense ? 20 : 22),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
        SizedBox(height: dense ? 10 : 16),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: dense ? 15 : 17,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: dense ? 2 : 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.3,
            fontSize: dense ? 12 : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ],
    );
  }
}
