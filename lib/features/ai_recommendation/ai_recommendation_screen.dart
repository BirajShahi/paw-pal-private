import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import '../pets/pet_model.dart';
import '../pets/pet_providers.dart';
import 'ai_recommendation_providers.dart';
import 'ai_recommendation_repository.dart';
import 'ai_recommendation_request.dart';

class AiRecommendationScreen extends ConsumerStatefulWidget {
  const AiRecommendationScreen({super.key});

  @override
  ConsumerState<AiRecommendationScreen> createState() =>
      _AiRecommendationScreenState();
}

class _AiRecommendationScreenState
    extends ConsumerState<AiRecommendationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedPetId;
  bool _isSubmitting = false;
  int _descriptionLength = 0;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  void _onDescriptionChanged() {
    final length = _descriptionController.text.trim().length;
    if (length != _descriptionLength) {
      setState(() => _descriptionLength = length);
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  bool _canSubmit(List<PetModel> pets) {
    if (_isSubmitting) return false;
    if (_selectedPetId == null) return false;
    if (!pets.any((pet) => pet.id == _selectedPetId)) return false;
    return _descriptionLength >= 20 && _descriptionLength <= 1000;
  }

  Future<void> _submit(List<PetModel> pets) async {
    if (_isSubmitting || !_canSubmit(pets)) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final request = AiRecommendationRequest(
        petId: _selectedPetId!,
        ownerDescription: _descriptionController.text,
      );

      final result = await ref
          .read(aiRecommendationRepositoryProvider)
          .prepareRecommendation(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Secure analysis is ready. PawPal verified your pet and loaded '
            '${result.serviceCount} available services. AI recommendations '
            'will be generated in the next step.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.message);
    } on AiRecommendationException catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _submitError =
            'Could not prepare your recommendation. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _petOptionLabel(PetModel pet) {
    final breed = pet.breed?.trim();
    if (breed != null && breed.isNotEmpty) {
      return '${pet.name} — ${pet.species} · $breed';
    }
    return '${pet.name} — ${pet.species}';
  }

  @override
  Widget build(BuildContext context) {
    final petsAsync = ref.watch(currentOwnerPetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Service Finder')),
      body: SafeArea(
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
              return _NoPetsEmptyState(
                onAddPet: () => context.go(AppRoutes.petNew),
              );
            }
            return _buildForm(pets);
          },
        ),
      ),
    );
  }

  Widget _buildForm(List<PetModel> pets) {
    final selectedId = pets.any((pet) => pet.id == _selectedPetId)
        ? _selectedPetId
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 24.0;
        final theme = Theme.of(context);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Find the exact PawPal service your pet needs',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us about your pet’s current needs and we will '
                      'prepare a personalised service recommendation.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: selectedId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Pet'),
                      items: [
                        for (final pet in pets)
                          DropdownMenuItem(
                            value: pet.id,
                            child: Text(
                              _petOptionLabel(pet),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _selectedPetId = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Select a pet';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _descriptionController,
                      labelText: 'Describe what your pet needs today',
                      hintText:
                          'My Golden Retriever has a muddy coat, is shedding '
                          'heavily, has overgrown nails and becomes nervous '
                          'around loud dryers.',
                      maxLines: 6,
                      enabled: !_isSubmitting,
                      validator: validateAiRecommendationDescription,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$_descriptionLength / 1000',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mention details such as coat condition, shedding, nail '
                      'condition, age, mobility needs, behaviour around other '
                      'pets, grooming anxiety, medication schedule, or whether '
                      'you need walking, home care or overnight supervision.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    _SafetyNotice(
                      icon: Icons.info_outline,
                      message:
                          'PawPal recommends pet-care services only. It does '
                          'not diagnose medical conditions or replace '
                          'professional veterinary advice.',
                    ),
                    const SizedBox(height: 12),
                    _SafetyNotice(
                      icon: Icons.emergency_outlined,
                      message:
                          'If your pet is seriously injured, struggling to '
                          'breathe, having a seizure or showing another urgent '
                          'symptom, contact a veterinarian immediately.',
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 16),
                      ErrorMessage(message: _submitError!),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Find the Best Service',
                      isLoading: _isSubmitting,
                      onPressed: _canSubmit(pets) ? () => _submit(pets) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}

class _NoPetsEmptyState extends StatelessWidget {
  const _NoPetsEmptyState({required this.onAddPet});

  final VoidCallback onAddPet;

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
                Icons.pets,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Add a pet to get started',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A pet profile is required for personalised service '
                'recommendations.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddPet,
                icon: const Icon(Icons.add),
                label: const Text('Add a Pet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
