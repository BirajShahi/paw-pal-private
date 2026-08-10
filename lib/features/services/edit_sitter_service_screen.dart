import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'add_sitter_service_screen.dart';
import 'service_model.dart';
import 'sitter_service_model.dart';
import 'sitter_service_providers.dart';
import 'sitter_service_repository.dart';

class EditSitterServiceScreen extends ConsumerStatefulWidget {
  const EditSitterServiceScreen({super.key, required this.offeringId});

  final String offeringId;

  @override
  ConsumerState<EditSitterServiceScreen> createState() =>
      _EditSitterServiceScreenState();
}

class _EditSitterServiceScreenState
    extends ConsumerState<EditSitterServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  bool _fieldsInitialised = false;
  bool _isActive = true;
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

  void _prefill(SitterServiceModel offering) {
    if (_fieldsInitialised) return;
    final price = offering.price;
    _priceController.text = price % 1 == 0
        ? price.toInt().toString()
        : price.toString();
    _durationController.text =
        offering.estimatedDurationMinutes?.toString() ?? '';
    _notesController.text = offering.serviceNotes ?? '';
    _isActive = offering.isActive;
    _fieldsInitialised = true;
  }

  Future<void> _save(SitterServiceModel offering) async {
    if (_isBusy) return;

    setState(() => _saveError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final price = double.parse(_priceController.text.trim());
    final durationText = _durationController.text.trim();
    final duration = durationText.isEmpty ? null : int.parse(durationText);
    final notesText = _notesController.text.trim();
    final notes = notesText.isEmpty ? null : notesText;
    final serviceName = offering.service?.name ?? 'Service';

    try {
      await ref
          .read(sitterServiceRepositoryProvider)
          .updateSitterService(
            offeringId: offering.id,
            price: price,
            estimatedDurationMinutes: duration,
            serviceNotes: notes,
            isActive: _isActive,
          );

      ref.invalidate(currentSitterServicesProvider);
      ref.invalidate(sitterServiceByIdProvider(offering.id));
      ref.invalidate(activeOfferingsForServiceProvider(offering.serviceId));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$serviceName was updated.')));
      context.go(AppRoutes.sitterServices);
    } on SitterServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = error.message;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Could not update this service. Please try again.';
        _isSaving = false;
      });
    }
  }

  Future<void> _delete(SitterServiceModel offering) async {
    if (_isBusy) return;

    setState(() => _saveError = null);

    final serviceName = offering.service?.name ?? 'this service';
    final serviceId = offering.serviceId;
    final offeringId = offering.id;

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _DeleteSitterServiceDialog(
          serviceName: serviceName,
          onConfirmed: () => ref
              .read(sitterServiceRepositoryProvider)
              .deleteSitterService(offeringId),
        );
      },
    );

    if (deleted != true || !mounted) return;

    ref.invalidate(currentSitterServicesProvider);
    ref.invalidate(sitterServiceByIdProvider(offeringId));
    ref.invalidate(activeOfferingsForServiceProvider(serviceId));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$serviceName was removed.')));
    context.go(AppRoutes.sitterServices);
  }

  @override
  Widget build(BuildContext context) {
    final offeringAsync = ref.watch(
      sitterServiceByIdProvider(widget.offeringId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Edit service')),
      body: SafeArea(
        child: offeringAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading service…'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorMessage(
                message: error.toString(),
                onRetry: () {
                  _fieldsInitialised = false;
                  ref.invalidate(sitterServiceByIdProvider(widget.offeringId));
                },
              ),
            ),
          ),
          data: (offering) {
            _prefill(offering);
            return _buildForm(offering);
          },
        ),
      ),
    );
  }

  Widget _buildForm(SitterServiceModel offering) {
    final service = offering.service;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: AppContentContainer(
        maxWidth: AppContentWidth.form,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (service != null)
                AppFormSection(
                  title: 'Service Information',
                  icon: Icons.miscellaneous_services_outlined,
                  children: [_ReadOnlyServiceDetails(service: service)],
                ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Pricing & Duration',
                icon: Icons.payments_outlined,
                children: [
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
                  AppTextField(
                    controller: _durationController,
                    labelText: 'Estimated duration (optional)',
                    hintText: 'e.g. 30, 60, 120 minutes',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    enabled: !_isBusy,
                    validator: validateSitterServiceDuration,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Provider Notes',
                icon: Icons.notes_outlined,
                children: [
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
                ],
              ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Availability Status',
                icon: Icons.visibility_outlined,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isActive
                          ? 'Active — visible to pet owners'
                          : 'Inactive — temporarily hidden from pet owners',
                    ),
                    value: _isActive,
                    onChanged: _isBusy
                        ? null
                        : (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_saveError != null) ...[
                ErrorMessage(message: _saveError!),
                const SizedBox(height: 16),
              ],
              PrimaryButton(
                label: 'Save changes',
                isLoading: _isSaving,
                onPressed: _isBusy ? null : () => _save(offering),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isBusy ? null : () => _delete(offering),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Delete Service'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyServiceDetails extends StatelessWidget {
  const _ReadOnlyServiceDetails({required this.service});

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
          ],
        ),
      ),
    );
  }
}

class _DeleteSitterServiceDialog extends StatefulWidget {
  const _DeleteSitterServiceDialog({
    required this.serviceName,
    required this.onConfirmed,
  });

  final String serviceName;
  final Future<void> Function() onConfirmed;

  @override
  State<_DeleteSitterServiceDialog> createState() =>
      _DeleteSitterServiceDialogState();
}

class _DeleteSitterServiceDialogState
    extends State<_DeleteSitterServiceDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _onRemovePressed() async {
    if (_isDeleting) return;

    setState(() {
      _errorMessage = null;
      _isDeleting = true;
    });

    try {
      await widget.onConfirmed();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: Text('Remove ${widget.serviceName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This service will be removed from your PawPal offerings. You '
              'can add it again later.',
            ),
            if (_isDeleting) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isDeleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _isDeleting ? null : _onRemovePressed,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove Service'),
          ),
        ],
      ),
    );
  }
}
