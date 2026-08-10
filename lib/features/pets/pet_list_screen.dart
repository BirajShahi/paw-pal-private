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
              onAction: () => context.go(AppRoutes.petNew),
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
                              onPressed: () => context.go(AppRoutes.petNew),
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
                                ? GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: pets.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 380,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 1.55,
                                        ),
                                    itemBuilder: (context, index) {
                                      return _PetCard(pet: pets[index]);
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
    final ageLabel = PetListScreen.formatAge(pet.ageYears);
    final breed = pet.breed?.trim();
    final chips = <String>[
      ?ageLabel,
      if (pet.size != null && pet.size!.isNotEmpty) pet.size!,
      if (pet.coatType != null && pet.coatType!.isNotEmpty) pet.coatType!,
    ];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(AppRoutes.petEdit(pet.id)),
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
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final chip in chips)
                            Chip(
                              label: Text(chip),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => context.go(AppRoutes.petEdit(pet.id)),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
