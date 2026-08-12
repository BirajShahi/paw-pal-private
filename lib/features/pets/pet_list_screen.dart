import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import 'pet_model.dart';
import 'pet_providers.dart';

class PetListScreen extends ConsumerWidget {
  const PetListScreen({super.key});

  static String? formatAge(double? ageYears) {
    if (ageYears == null) return null;
    if (ageYears == 1) return '1 year';
    if (ageYears == ageYears.roundToDouble() && ageYears > 1) {
      return '${ageYears.toInt()} years';
    }
    if (ageYears == 0) return '0 years';
    final text = ageYears % 1 == 0
        ? ageYears.toInt().toString()
        : ageYears.toString();
    return '$text years';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentOwnerPetsProvider);
    await ref.read(currentOwnerPetsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(currentOwnerPetsProvider);

    return SafeArea(
      child: petsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading pets…'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorMessage(
              message: error.toString(),
              onRetry: () => ref.invalidate(currentOwnerPetsProvider),
            ),
          ),
        ),
        data: (pets) {
          if (pets.isEmpty) {
            return AppEmptyState(
              icon: Icons.pets_outlined,
              title: 'No pets yet',
              message:
                  'Add a pet profile to enable personalised care and AI service '
                  'recommendations such as Full Grooming, Wash and Dry, '
                  'De-shedding and Nail Clipping.',
              actionLabel: 'Add pet',
              onAction: () => context.push(AppRoutes.petNew),
              secondaryLabel: 'Refresh',
              onSecondary: () => ref.invalidate(currentOwnerPetsProvider),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;

              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: AppContentContainer(
                        maxWidth: AppContentWidth.page,
                        padding: EdgeInsets.fromLTRB(
                          constraints.maxWidth > 600 ? 24 : 16,
                          12,
                          constraints.maxWidth > 600 ? 24 : 16,
                          8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Your pets',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (kIsWeb)
                              IconButton(
                                tooltip: 'Refresh',
                                onPressed: () => _refresh(ref),
                                icon: const Icon(Icons.refresh),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: () => context.push(AppRoutes.petNew),
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth > 600 ? 24 : 16,
                        vertical: 8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppContentWidth.page,
                            ),
                            child: wide
                                ? LayoutBuilder(
                                    builder: (context, gridConstraints) {
                                      const maxCardWidth = 380.0;
                                      const spacing = 12.0;
                                      final available =
                                          gridConstraints.maxWidth;
                                      final columns =
                                          (available / (maxCardWidth + spacing))
                                              .floor()
                                              .clamp(1, 4);
                                      final cardWidth =
                                          (available -
                                              spacing * (columns - 1)) /
                                          columns;

                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: spacing,
                                        children: [
                                          for (final pet in pets)
                                            SizedBox(
                                              width: cardWidth,
                                              child: _PetCard(pet: pet),
                                            ),
                                        ],
                                      );
                                    },
                                  )
                                : Column(
                                    children: [
                                      for (final pet in pets) ...[
                                        _PetCard(pet: pet),
                                        const SizedBox(height: 12),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ageLabel = PetListScreen.formatAge(pet.ageYears)?.trim();
    final breed = pet.breed?.trim();
    final sizeLabel = _formatSizeLabel(pet.size);
    final coatType = pet.coatType?.trim();
    final chips = <String>[
      if (ageLabel != null && ageLabel.isNotEmpty) ageLabel,
      ?sizeLabel,
      if (coatType != null && coatType.isNotEmpty) coatType,
    ];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(AppRoutes.petEdit(pet.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.pets, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      breed != null && breed.isNotEmpty
                          ? '${pet.species} · $breed'
                          : pet.species,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final chip in chips)
                            Chip(
                              label: Text(chip),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              backgroundColor: scheme.surfaceContainerHigh,
                              side: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                              labelStyle: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => context.push(AppRoutes.petEdit(pet.id)),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Maps stored size wire values to readable chip labels.
  static String? _formatSizeLabel(String? size) {
    final value = size?.trim();
    if (value == null || value.isEmpty) return null;
    switch (value.toLowerCase()) {
      case 'small':
        return 'Small';
      case 'medium':
        return 'Medium';
      case 'large':
        return 'Large';
      default:
        return value;
    }
  }
}
