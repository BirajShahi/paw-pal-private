import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import '../pets/pet_model.dart';
import '../pets/pet_providers.dart';
import '../services/sitter_service_model.dart';
import '../services/sitter_service_providers.dart';
import '../services/sitter_service_repository.dart';
import '../services/sitter_services_screen.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';
import 'create_booking_request.dart';

/// Owner booking request form for a specific active sitter-service offering.
class CreateBookingScreen extends ConsumerStatefulWidget {
  const CreateBookingScreen({
    super.key,
    required this.offeringId,
    @visibleForTesting this.debugInitialDate,
    @visibleForTesting this.debugInitialTime,
    @visibleForTesting this.debugInitialPetId,
  });

  final String offeringId;

  /// Test-only seed values so widget tests avoid flaky system pickers.
  final DateTime? debugInitialDate;
  final TimeOfDay? debugInitialTime;
  final String? debugInitialPetId;

  @override
  ConsumerState<CreateBookingScreen> createState() =>
      _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  final _notesController = TextEditingController();

  String? _selectedPetId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;
  String? _formError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.debugInitialDate;
    _selectedTime = widget.debugInitialTime;
    _selectedPetId = widget.debugInitialPetId;
    _notesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _isBusy => _isSaving;

  DateTime? get _combinedDateTime {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  bool _hasRequiredSelections(List<PetModel> pets) {
    return pets.isNotEmpty &&
        _selectedPetId != null &&
        _selectedDate != null &&
        _selectedTime != null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _formError = null;
      _submitError = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedTime = picked;
      _formError = null;
      _submitError = null;
    });
  }

  Future<void> _submit({
    required SitterServiceModel offering,
    required List<PetModel> pets,
  }) async {
    if (_isBusy) return;

    setState(() {
      _formError = null;
      _submitError = null;
    });

    if (pets.isEmpty) {
      setState(() {
        _formError = 'Add a pet before making a booking.';
      });
      return;
    }

    if (_selectedPetId == null) {
      setState(() => _formError = 'Please select a pet.');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _formError = 'Please select a booking date.');
      return;
    }
    if (_selectedTime == null) {
      setState(() => _formError = 'Please select a booking time.');
      return;
    }

    final requestedStart = _combinedDateTime!;
    if (!requestedStart.isAfter(DateTime.now())) {
      setState(() {
        _formError = 'Please select a future booking date and time.';
      });
      return;
    }

    final notes = _notesController.text;
    if (notes.trim().length > 1000) {
      setState(() {
        _formError = 'Owner notes may contain up to 1000 characters.';
      });
      return;
    }

    setState(() => _isSaving = true);

    try {
      final request = CreateBookingRequest(
        petId: _selectedPetId!,
        sitterServiceId: widget.offeringId,
        requestedStart: requestedStart,
        ownerNotes: notes,
      );

      final booking = await ref
          .read(bookingRepositoryProvider)
          .createBooking(request);

      ref.invalidate(currentOwnerBookingsProvider);
      ref.invalidate(bookingByIdProvider(booking.id));

      if (!mounted) return;

      final serviceName = offering.service?.name.trim().isNotEmpty == true
          ? offering.service!.name
          : 'this service';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking request sent for $serviceName.')),
      );
      context.go(AppRoutes.bookings);
    } on BookingException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _submitError = error.message;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _submitError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _submitError = 'Unable to create this booking. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringAsync = ref.watch(
      activeSitterOfferingByIdProvider(widget.offeringId),
    );
    final petsAsync = ref.watch(currentOwnerPetsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: appBackLeading(context, fallbackRoute: AppRoutes.sitters),
        title: const Text('Request Booking'),
      ),
      body: offeringAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading service…'),
        error: (error, _) => ErrorMessage(
          message: error is SitterServiceException
              ? error.message
              : 'This service offering is unavailable.',
          onRetry: () => ref.invalidate(
            activeSitterOfferingByIdProvider(widget.offeringId),
          ),
        ),
        data: (offering) {
          return petsAsync.when(
            loading: () => const LoadingIndicator(message: 'Loading pets…'),
            error: (error, _) => ErrorMessage(
              message: error.toString(),
              onRetry: () => ref.invalidate(currentOwnerPetsProvider),
            ),
            data: (pets) => _buildForm(context, offering: offering, pets: pets),
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context, {
    required SitterServiceModel offering,
    required List<PetModel> pets,
  }) {
    final theme = Theme.of(context);
    final sitter = offering.sitter!;
    final serviceName = offering.service?.name ?? 'Service';
    final location = formatBookingLocation(sitter.suburb, sitter.postcode);
    final notesLength = _notesController.text.trim().length;
    final selectedPet = _selectedPetId == null
        ? null
        : pets.where((pet) => pet.id == _selectedPetId).firstOrNull;
    final canSubmit = _hasRequiredSelections(pets) && !_isBusy;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: AppContentContainer(
          maxWidth: AppContentWidth.form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(serviceName, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(sitter.fullName, style: theme.textTheme.titleMedium),
                      if (location != null) ...[
                        const SizedBox(height: 4),
                        Text(location, style: theme.textTheme.bodySmall),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        SitterServicesScreen.formatPrice(offering.price),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (offering.estimatedDurationMinutes != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Estimated duration: '
                          '${SitterServicesScreen.formatDuration(offering.estimatedDurationMinutes!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (offering.serviceNotes != null &&
                          offering.serviceNotes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          offering.serviceNotes!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Pet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (pets.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'You need to add a pet before making a booking.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Add a Pet',
                          onPressed: _isBusy
                              ? null
                              : () => context.push(AppRoutes.petNew),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: RadioGroup<String>(
                    groupValue: _selectedPetId,
                    onChanged: _isBusy
                        ? (_) {}
                        : (value) {
                            setState(() {
                              _selectedPetId = value;
                              _formError = null;
                              _submitError = null;
                            });
                          },
                    child: Column(
                      children: [
                        for (final pet in pets)
                          RadioListTile<String>(
                            value: pet.id,
                            title: Text(pet.name),
                            subtitle: Text(
                              [
                                pet.species,
                                if (pet.breed != null &&
                                    pet.breed!.trim().isNotEmpty)
                                  pet.breed!.trim(),
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (pets.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Date', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _selectedDate == null
                        ? 'Select date'
                        : formatBookingDate(_selectedDate!),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Time', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _pickTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    _selectedTime == null
                        ? 'Select time'
                        : _selectedTime!.format(context),
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _notesController,
                  labelText: 'Notes for the sitter',
                  hintText:
                      'Include any care instructions the sitter should know '
                      'for this booking.',
                  maxLines: 4,
                  enabled: !_isBusy,
                  onChanged: (_) {
                    setState(() {
                      _formError = null;
                      _submitError = null;
                    });
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$notesLength / 1000',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Booking summary', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(label: 'Service', value: serviceName),
                        _SummaryRow(label: 'Provider', value: sitter.fullName),
                        _SummaryRow(
                          label: 'Pet',
                          value: selectedPet?.name ?? 'Not selected',
                        ),
                        _SummaryRow(
                          label: 'Date',
                          value: _selectedDate == null
                              ? 'Not selected'
                              : formatBookingDate(_selectedDate!),
                        ),
                        _SummaryRow(
                          label: 'Time',
                          value: _selectedTime == null
                              ? 'Not selected'
                              : _selectedTime!.format(context),
                        ),
                        _SummaryRow(
                          label: 'Price',
                          value: SitterServicesScreen.formatPrice(
                            offering.price,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your request will be sent to the sitter for approval.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _formError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _submitError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  key: const Key('request_booking_button'),
                  label: 'Request Booking',
                  isLoading: _isSaving,
                  onPressed: canSubmit
                      ? () => _submit(offering: offering, pets: pets)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Formats suburb and postcode for booking display.
@visibleForTesting
String? formatBookingLocation(String? suburb, String? postcode) {
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

/// Local date label without pulling in an extra package.
String formatBookingDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Combines a local date and time into one local DateTime.
@visibleForTesting
DateTime combineBookingDateTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
