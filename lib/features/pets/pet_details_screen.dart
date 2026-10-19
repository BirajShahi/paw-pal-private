import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'pet_list_screen.dart';
import 'pet_model.dart';
import 'pet_providers.dart';

/// Read-only pet profile opened from the pets list.
///
/// The list card shows a short summary. This screen shows the full profile,
/// including notes that are not on the card.
class PetDetailsScreen extends ConsumerWidget {
  const PetDetailsScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petByIdProvider(petId));

    return Scaffold(
      appBar: AppBar(
        leading: appBackLeading(context, fallbackRoute: AppRoutes.pets),
        title: const Text('Pet details'),
      ),
      body: SafeArea(
        child: petAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading pet…'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorMessage(
                message: error.toString(),
                onRetry: () => ref.invalidate(petByIdProvider(petId)),
              ),
            ),
          ),
          data: (pet) => _PetDetailsBody(pet: pet),
        ),
      ),
    );
  }
}

class _PetDetailsBody extends StatelessWidget {
  const _PetDetailsBody({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breed = pet.breed?.trim();
    final age = PetListScreen.formatAge(pet.ageYears);
    final size = _sizeLabel(pet.size);

    return SingleChildScrollView(
      child: AppContentContainer(
        maxWidth: AppContentWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(pet.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              breed != null && breed.isNotEmpty
                  ? '${pet.species} · $breed'
                  : pet.species,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            AppFormSection(
              title: 'Profile',
              icon: Icons.pets_outlined,
              children: [
                _DetailRow(label: 'Species', value: pet.species),
                _DetailRow(
                  label: 'Breed',
                  value: breed == null || breed.isEmpty
                      ? 'Not recorded'
                      : breed,
                ),
                _DetailRow(label: 'Age', value: age ?? 'Not recorded'),
                _DetailRow(label: 'Size', value: size ?? 'Not recorded'),
                _DetailRow(
                  label: 'Coat type',
                  value: _textOrNotRecorded(pet.coatType),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppFormSection(
              title: 'Notes',
              icon: Icons.notes_outlined,
              children: [
                _DetailRow(
                  label: 'Medical',
                  value: _textOrNotRecorded(pet.medicalNotes),
                ),
                _DetailRow(
                  label: 'Behaviour',
                  value: _textOrNotRecorded(pet.behaviourNotes),
                ),
                _DetailRow(
                  label: 'Care instructions',
                  value: _textOrNotRecorded(pet.careNotes),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Edit pet',
              icon: Icons.edit_outlined,
              onPressed: () => context.push(AppRoutes.petEdit(pet.id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

String _textOrNotRecorded(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return 'Not recorded';
  return text;
}

String? _sizeLabel(String? size) {
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
