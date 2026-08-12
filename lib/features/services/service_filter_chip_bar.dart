import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'service_model.dart';

/// Horizontally scrollable service filter chips for Sitters and Map.
///
/// Preserves selection callbacks only — no data fetching.
class ServiceFilterChipBar extends StatelessWidget {
  const ServiceFilterChipBar({
    super.key,
    required this.services,
    required this.selectedServiceId,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final List<ServiceModel> services;
  final String? selectedServiceId;
  final ValueChanged<String?> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final namedServices = [
      for (final service in services)
        if (service.name.trim().isNotEmpty) service,
    ];
    final allSelected = selectedServiceId == null || selectedServiceId!.isEmpty;

    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ServiceFilterChip(
                label: 'All Services',
                selected: allSelected,
                onSelected: (_) => onSelected(null),
              ),
            ),
            for (final service in namedServices)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ServiceFilterChip(
                  label: service.name.trim(),
                  selected: selectedServiceId == service.id,
                  onSelected: (_) => onSelected(service.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFilterChip extends StatelessWidget {
  const _ServiceFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.secondaryDark
        : AppColors.onSurfaceVariant;
    final borderColor = selected
        ? AppColors.secondary.withValues(alpha: 0.4)
        : AppColors.outlineVariant.withValues(alpha: 0.75);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: AppColors.secondaryContainer,
      backgroundColor: AppColors.surface,
      checkmarkColor: foreground,
      side: BorderSide(color: borderColor),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: foreground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
    );
  }
}
