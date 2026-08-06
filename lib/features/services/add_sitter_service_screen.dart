import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'service_model.dart';
import 'service_providers.dart';
import 'sitter_service_model.dart';
import 'sitter_service_providers.dart';
import 'sitter_service_repository.dart';

/// Catalogue services not already offered by the sitter (active or inactive).
List<ServiceModel> availableCatalogueServices({
  required List<ServiceModel> catalogue,
  required List<SitterServiceModel> offerings,
}) {
  final offeredIds = {for (final offering in offerings) offering.serviceId};
  return [
    for (final service in catalogue)
      if (!offeredIds.contains(service.id)) service,
  ];
}

String? validateSitterServicePrice(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return 'Price is required';
  }
  final price = double.tryParse(raw);
  if (price == null) {
    return 'Enter a valid number';
  }
  if (price <= 0 || price > 1000) {
    return 'Price must be greater than 0 and at most 1000';
  }
  return null;
}

String? validateSitterServiceDuration(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  final duration = int.tryParse(raw);
  if (duration == null) {
    return 'Enter whole minutes only';
  }
  if (duration < 15 || duration > 1440) {
    return 'Duration must be between 15 and 1440 minutes';
  }
  return null;
}

String? validateSitterServiceNotes(String? value) {
  final notes = value?.trim() ?? '';
  if (notes.length > 500) {
    return 'Service notes may contain up to 500 characters';
  }
  return null;
}

bool isDuplicateSitterServiceError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('23505') ||
      text.contains('duplicate') ||
      text.contains('unique');
}

class AddSitterServiceScreen extends ConsumerStatefulWidget {
  const AddSitterServiceScreen({super.key});

  @override
  ConsumerState<AddSitterServiceScreen> createState() =>
      _AddSitterServiceScreenState();
}

class _AddSitterServiceScreenState
    extends ConsumerState<AddSitterServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedServiceId;
  bool _isSaving = false;
  String? _saveError;

  bool get _isBusy => _isSaving;

  @override
  void dispose() {
    _priceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<ServiceModel> available) async {
    if (_isBusy) return;

    setState(() => _saveError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final selectedId = _selectedServiceId;
    if (selectedId == null) return;

    ServiceModel? selected;
    for (final service in available) {
      if (service.id == selectedId) {
        selected = service;
        break;
      }
    }
    if (selected == null) return;

    setState(() => _isSaving = true);

    final price = double.parse(_priceController.text.trim());
    final durationText = _durationController.text.trim();
    final duration = durationText.isEmpty ? null : int.parse(durationText);
    final notesText = _notesController.text.trim();
    final notes = notesText.isEmpty ? null : notesText;

    try {
      await ref
          .read(sitterServiceRepositoryProvider)
          .createSitterService(
            serviceId: selected.id,
            price: price,
            estimatedDurationMinutes: duration,
            serviceNotes: notes,
          );

      ref.invalidate(currentSitterServicesProvider);
      ref.invalidate(activeOfferingsForServiceProvider(selected.id));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.name} was added to your services.')),
      );
      context.go(AppRoutes.sitterServices);
    } on SitterServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = isDuplicateSitterServiceError(error)
            ? 'You already offer this service.'
            : error.message;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = isDuplicateSitterServiceError(error)
            ? 'You already offer this service.'
            : 'Could not add this service. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(activeServicesProvider);
    final offeringsAsync = ref.watch(currentSitterServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add service')),
      body: SafeArea(
        child: catalogueAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading services…'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorMessage(
                message: error.toString(),
                onRetry: () => ref.invalidate(activeServicesProvider),
              ),
            ),
          ),
          data: (catalogue) {
            return offeringsAsync.when(
              loading: () =>
                  const LoadingIndicator(message: 'Loading services…'),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorMessage(
                    message: error.toString(),
                    onRetry: () =>
                        ref.invalidate(currentSitterServicesProvider),
                  ),
                ),
              ),
              data: (offerings) {
                final available = availableCatalogueServices(
                  catalogue: catalogue,
                  offerings: offerings,
                );

                if (available.isEmpty) {
                  return _AllServicesAddedState(
                    onBack: () => context.go(AppRoutes.sitterServices),
                  );
                }

                return _buildForm(available);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(List<ServiceModel> available) {
    final selectedId = available.any((s) => s.id == _selectedServiceId)
        ? _selectedServiceId
        : null;

    ServiceModel? selected;
    for (final service in available) {
      if (service.id == selectedId) {
        selected = service;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 24.0;

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
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: selectedId,
                      decoration: const InputDecoration(labelText: 'Service'),
                      items: [
                        for (final service in available)
                          DropdownMenuItem(
                            value: service.id,
                            child: Text(
                              '${service.name} — ${service.category.displayName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _isBusy
                          ? null
                          : (value) =>
                                setState(() => _selectedServiceId = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Select a service';
                        }
                        return null;
                      },
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 16),
                      _ServiceDetailsCard(service: selected),
                    ],
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _priceController,
                      labelText: 'Price',
                      hintText: 'e.g. 20, 45.50, 120',
                      prefixText: '\$ ',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      enabled: !_isBusy,
                      validator: validateSitterServicePrice,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _durationController,
                      labelText: 'Estimated duration (optional)',
                      hintText: 'e.g. 30, 60, 120 minutes',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enabled: !_isBusy,
                      validator: validateSitterServiceDuration,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Examples: 30 minutes, 60 minutes, 120 minutes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _notesController,
                      labelText: 'Service notes (optional)',
                      hintText:
                          'Describe what clients should know about how you '
                          'provide this service.',
                      maxLines: 4,
                      enabled: !_isBusy,
                      validator: validateSitterServiceNotes,
                    ),
                    const SizedBox(height: 24),
                    if (_saveError != null) ...[
                      ErrorMessage(message: _saveError!),
                      const SizedBox(height: 16),
                    ],
                    PrimaryButton(
                      label: 'Add Service',
                      isLoading: _isSaving,
                      onPressed: _isBusy ? null : () => _submit(available),
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

class _ServiceDetailsCard extends StatelessWidget {
  const _ServiceDetailsCard({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              service.category.displayName,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(service.description, style: theme.textTheme.bodyMedium),
            if (service.includedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Included', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final item in service.includedItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $item', style: theme.textTheme.bodyMedium),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              service.canBeAddOn
                  ? 'May be used as an add-on'
                  : 'Not available as an add-on',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AllServicesAddedState extends StatelessWidget {
  const _AllServicesAddedState({required this.onBack});

  final VoidCallback onBack;

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
                Icons.check_circle_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'You have already added every available PawPal service.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onBack,
                child: const Text('Back to My services'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
