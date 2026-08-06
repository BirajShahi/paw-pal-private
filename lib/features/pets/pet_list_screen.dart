import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
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
            return _EmptyPetsState(
              onRefresh: () => ref.invalidate(currentOwnerPetsProvider),
              onAdd: () => context.go(AppRoutes.petNew),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              final horizontalPadding = constraints.maxWidth > 600
                  ? 48.0
                  : 16.0;

              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        24,
                      ),
                      sliver: SliverToBoxAdapter(
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
                            IconButton(
                              tooltip: 'Add pet',
                              onPressed: () => context.go(AppRoutes.petNew),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: wide
                          ? SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 360,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.35,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return _PetCard(pet: pets[index]);
                              }, childCount: pets.length),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PetCard(pet: pets[index]),
                                );
                              }, childCount: pets.length),
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

class _EmptyPetsState extends StatelessWidget {
  const _EmptyPetsState({required this.onRefresh, required this.onAdd});

  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No pets yet',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Add a pet profile to enable personalised care and AI service '
                'recommendations such as Full Grooming, Wash and Dry, '
                'De-shedding and Nail Clipping.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add pet'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final ageLabel = PetListScreen.formatAge(pet.ageYears);
    final details = <String>[
      pet.species,
      if (pet.breed != null && pet.breed!.isNotEmpty) pet.breed!,
      ?ageLabel,
      if (pet.size != null && pet.size!.isNotEmpty) pet.size!,
      if (pet.coatType != null && pet.coatType!.isNotEmpty) pet.coatType!,
    ];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(AppRoutes.petEdit(pet.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.pets,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details.join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
