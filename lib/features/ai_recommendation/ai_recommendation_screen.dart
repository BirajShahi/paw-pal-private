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
import '../services/sitter_service_model.dart';
import '../services/sitter_service_providers.dart';
import '../services/sitter_services_screen.dart';
import 'ai_recommendation_providers.dart';
import 'ai_recommendation_repository.dart';
import 'ai_recommendation_request.dart';
import 'ai_service_recommendation_result.dart';

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
  AiServiceRecommendationResult? _result;

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
      _result = null;
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
          .recommendService(request);

      if (!mounted) return;
      setState(() => _result = result);
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
            'PawPal could not generate a recommendation right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _tryAgain(List<PetModel> pets) {
    setState(() {
      _result = null;
      _submitError = null;
    });
    _submit(pets);
  }

  String? get _matchServiceCode {
    final result = _result;
    if (result == null) return null;
    if (result.outcome != AiRecommendationOutcome.serviceRecommendation) {
      return null;
    }
    final code = result.primaryService?.code.trim() ?? '';
    if (code.isEmpty) return null;
    return code;
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
    final matchCode = _matchServiceCode;
    final recommendedServiceName = _result?.primaryService?.name;

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
                    if (_result != null) ...[
                      const SizedBox(height: 24),
                      _RecommendationResultCard(result: _result!),
                      if (matchCode != null &&
                          recommendedServiceName != null) ...[
                        const SizedBox(height: 24),
                        _MatchingProvidersSection(
                          serviceCode: matchCode,
                          recommendedServiceName: recommendedServiceName,
                        ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _tryAgain(pets),
                        child: const Text('Try Again'),
                      ),
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

class _MatchingProvidersSection extends ConsumerWidget {
  const _MatchingProvidersSection({
    required this.serviceCode,
    required this.recommendedServiceName,
  });

  final String serviceCode;
  final String recommendedServiceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final matchesAsync = ref.watch(
      activeSitterMatchesByServiceCodeProvider(serviceCode),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Providers offering this service',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh providers',
              onPressed: () {
                ref.invalidate(
                  activeSitterMatchesByServiceCodeProvider(serviceCode),
                );
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'These PawPal providers currently offer the recommended service.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        matchesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LoadingIndicator(message: 'Loading providers…'),
          ),
          error: (error, _) => ErrorMessage(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(
                activeSitterMatchesByServiceCodeProvider(serviceCode),
              );
            },
          ),
          data: (offerings) {
            if (offerings.isEmpty) {
              return const _ProvidersEmptyState();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final offering in offerings) ...[
                  _ProviderMatchCard(
                    offering: offering,
                    fallbackServiceName: recommendedServiceName,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProvidersEmptyState extends StatelessWidget {
  const _ProvidersEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No providers currently offer this exact service.',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'You can try again later or review the recommended service with '
              'a local pet-care provider.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderMatchCard extends StatelessWidget {
  const _ProviderMatchCard({
    required this.offering,
    required this.fallbackServiceName,
  });

  final SitterServiceModel offering;
  final String fallbackServiceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sitter = offering.sitter;
    if (sitter == null) {
      return const SizedBox.shrink();
    }

    final location = _locationLabel(sitter.suburb, sitter.postcode);
    final serviceName = offering.service?.name ?? fallbackServiceName;
    final duration = offering.estimatedDurationMinutes;
    final notes = offering.serviceNotes?.trim();
    final description = sitter.serviceDescription?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sitter.fullName, style: theme.textTheme.titleMedium),
            if (location != null) ...[
              const SizedBox(height: 4),
              Text(location, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Text(serviceName, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              SitterServicesScreen.formatPrice(offering.price),
              style: theme.textTheme.titleMedium,
            ),
            if (duration != null) ...[
              const SizedBox(height: 4),
              Text(
                'Estimated duration: '
                '${SitterServicesScreen.formatDuration(duration)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(notes, style: theme.textTheme.bodyMedium),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push(AppRoutes.bookingNew(offering.id)),
              child: const Text('Book This Service'),
            ),
          ],
        ),
      ),
    );
  }

  static String? _locationLabel(String? suburb, String? postcode) {
    final trimmedSuburb = suburb?.trim();
    final trimmedPostcode = postcode?.trim();
    final hasSuburb = trimmedSuburb != null && trimmedSuburb.isNotEmpty;
    final hasPostcode = trimmedPostcode != null && trimmedPostcode.isNotEmpty;

    if (hasSuburb && hasPostcode) {
      return '$trimmedSuburb $trimmedPostcode';
    }
    if (hasSuburb) return trimmedSuburb;
    if (hasPostcode) return trimmedPostcode;
    return null;
  }
}

class _RecommendationResultCard extends StatelessWidget {
  const _RecommendationResultCard({required this.result});

  final AiServiceRecommendationResult result;

  @override
  Widget build(BuildContext context) {
    if (result.outcome == AiRecommendationOutcome.urgentVet) {
      return _UrgentVetCard(result: result);
    }
    return _ServiceRecommendationCard(result: result);
  }
}

class _ServiceRecommendationCard extends StatelessWidget {
  const _ServiceRecommendationCard({required this.result});

  final AiServiceRecommendationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = result.primaryService!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recommended Service', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(primary.name, style: theme.textTheme.headlineSmall),
            if (result.additionalServices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Additional Services', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final service in result.additionalServices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${service.name}'),
                ),
            ],
            const SizedBox(height: 16),
            Text('Why this recommendation', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(result.reasoning),
            if (result.sitterRequirements.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Look for a provider who can:',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final item in result.sitterRequirements)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item'),
                ),
            ],
            const SizedBox(height: 16),
            Text('Next step', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(result.ownerAdvice),
            const SizedBox(height: 16),
            Text(result.safetyNotice, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _UrgentVetCard extends StatelessWidget {
  const _UrgentVetCard({required this.result});

  final AiServiceRecommendationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contact a veterinarian immediately',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'PawPal is not recommending a pet-care service for this request.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.reasoning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.ownerAdvice,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.safetyNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
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
