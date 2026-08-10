import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import '../services/sitter_services_screen.dart';
import 'booking_model.dart';
import 'booking_payment_status.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';
import 'booking_status.dart';
import 'card_payment_validators.dart';
import 'create_booking_screen.dart';
import 'owner_bookings_screen.dart';

/// Simulated card checkout for accepted unpaid owner bookings.
///
/// Card field values stay in memory only and are never sent to repositories.
class CardPaymentScreen extends ConsumerStatefulWidget {
  const CardPaymentScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends ConsumerState<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _isSubmitting = false;
  bool _paymentSucceeded = false;
  String? _submitError;
  BookingModel? _paidBooking;

  @override
  void dispose() {
    _clearCardFields();
    _nameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _clearCardFields() {
    _nameController.clear();
    _cardNumberController.clear();
    _expiryController.clear();
    _cvvController.clear();
  }

  bool _isPayable(BookingModel booking) {
    return booking.status == BookingStatus.accepted &&
        booking.paymentStatus == BookingPaymentStatus.unpaid;
  }

  Future<void> _submit(BookingModel booking) async {
    if (_isSubmitting || _paymentSucceeded) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      // Intentionally pass only the booking id — never card field values.
      final paid = await ref
          .read(bookingRepositoryProvider)
          .demoPayBooking(booking.id);

      if (!mounted) return;

      _clearCardFields();
      ref.invalidate(currentOwnerBookingsProvider);
      ref.invalidate(bookingByIdProvider(booking.id));

      setState(() {
        _isSubmitting = false;
        _paymentSucceeded = true;
        _paidBooking = paid;
      });
    } on BookingException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'Unable to complete payment. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingByIdProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: bookingAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading booking…'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorMessage(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(bookingByIdProvider(widget.bookingId)),
              ),
            ),
          ),
          data: (booking) {
            if (_paymentSucceeded) {
              return _PaymentSuccessView(
                booking: _paidBooking ?? booking,
                onBack: () => context.go(AppRoutes.bookings),
              );
            }

            if (!_isPayable(booking)) {
              return _UnavailablePaymentView(
                onBack: () => context.go(AppRoutes.bookings),
              );
            }

            return _PaymentFormView(
              booking: booking,
              formKey: _formKey,
              nameController: _nameController,
              cardNumberController: _cardNumberController,
              expiryController: _expiryController,
              cvvController: _cvvController,
              isSubmitting: _isSubmitting,
              submitError: _submitError,
              onSubmit: () => _submit(booking),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentFormView extends StatelessWidget {
  const _PaymentFormView({
    required this.booking,
    required this.formKey,
    required this.nameController,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
    required this.isSubmitting,
    required this.submitError,
    required this.onSubmit,
  });

  final BookingModel booking;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final bool isSubmitting;
  final String? submitError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = SitterServicesScreen.formatPrice(booking.priceSnapshot);
    final localStart = booking.requestedStart.toLocal();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 16.0;
        final sideBySide = constraints.maxWidth >= 520;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            24,
          ),
          child: Center(
            child: AppContentContainer(
              maxWidth: AppContentWidth.form,
              padding: EdgeInsets.zero,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Booking Summary', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              booking.serviceNameSnapshot,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.petNameSnapshot,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${formatBookingDate(localStart)} • '
                              '${formatBookingTime(localStart)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 18),
                            Text('Amount', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 6),
                            Text(
                              '$amount AUD',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Details',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: nameController,
                              labelText: 'Cardholder Name',
                              hintText: 'Alex Smith',
                              textInputAction: TextInputAction.next,
                              enabled: !isSubmitting,
                              validator: validateCardholderName,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: cardNumberController,
                              enabled: !isSubmitting,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d ]'),
                                ),
                                LengthLimitingTextInputFormatter(19),
                              ],
                              onChanged: (value) {
                                final formatted = formatCardNumberGroups(value);
                                if (formatted == value) return;
                                cardNumberController.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(
                                    offset: formatted.length,
                                  ),
                                );
                              },
                              validator: validateCardNumber,
                              decoration: const InputDecoration(
                                labelText: 'Card Number',
                                hintText: '4242 4242 4242 4242',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (sideBySide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _ExpiryField(
                                      controller: expiryController,
                                      enabled: !isSubmitting,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _CvvField(
                                      controller: cvvController,
                                      enabled: !isSubmitting,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _ExpiryField(
                                controller: expiryController,
                                enabled: !isSubmitting,
                              ),
                              const SizedBox(height: 12),
                              _CvvField(
                                controller: cvvController,
                                enabled: !isSubmitting,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: 16),
                      ErrorMessage(message: submitError!),
                    ],
                    const SizedBox(height: 20),
                    KeyedSubtree(
                      key: const Key('confirm_card_payment'),
                      child: PrimaryButton(
                        label: isSubmitting
                            ? 'Processing payment…'
                            : 'Pay $amount',
                        isLoading: isSubmitting,
                        onPressed: isSubmitting ? null : onSubmit,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const AppInfoBanner(
                      message:
                          'Payment simulation for the PawPal university project.\n'
                          'No real card will be charged.',
                      icon: Icons.lock_outline,
                      dense: true,
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

class _ExpiryField extends StatelessWidget {
  const _ExpiryField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
        LengthLimitingTextInputFormatter(5),
      ],
      onChanged: (value) {
        final formatted = formatExpiryInput(value);
        if (formatted == value) return;
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      },
      validator: validateExpiryDate,
      decoration: const InputDecoration(
        labelText: 'Expiry Date',
        hintText: '12/28',
      ),
    );
  }
}

class _CvvField extends StatelessWidget {
  const _CvvField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      validator: validateCvv,
      decoration: const InputDecoration(labelText: 'CVV', hintText: '123'),
    );
  }
}

class _PaymentSuccessView extends StatelessWidget {
  const _PaymentSuccessView({required this.booking, required this.onBack});

  final BookingModel booking;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = SitterServicesScreen.formatPrice(booking.priceSnapshot);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 24.0;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payment successful',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your simulated card payment for '
                    '${booking.serviceNameSnapshot} has been completed.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Amount', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(
                            '$amount AUD',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Payment status',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: bookingPaymentStatusChip(
                              theme,
                              BookingPaymentStatus.demoPaid,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No real money was charged.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Back to Bookings', onPressed: onBack),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnavailablePaymentView extends StatelessWidget {
  const _UnavailablePaymentView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This booking is no longer available for payment.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Back to Bookings', onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}
