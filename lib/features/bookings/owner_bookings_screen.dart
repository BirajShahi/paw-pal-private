import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import '../services/sitter_services_screen.dart';
import 'booking_model.dart';
import 'booking_payment_status.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';
import 'booking_status.dart';
import 'create_booking_screen.dart';

/// Owner list of bookings for `/bookings`.
class OwnerBookingsScreen extends ConsumerWidget {
  const OwnerBookingsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentOwnerBookingsProvider);
    await ref.read(currentOwnerBookingsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(currentOwnerBookingsProvider);

    return SafeArea(
      child: bookingsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading bookings…'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorMessage(
              message: error is BookingException
                  ? error.message
                  : error.toString(),
              onRetry: () => ref.invalidate(currentOwnerBookingsProvider),
            ),
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return _EmptyBookingsState(
              onRefresh: () => _refresh(ref),
              onFindService: () => context.go(AppRoutes.aiRecommendation),
            );
          }

          final sections = partitionOwnerBookings(bookings);

          return LayoutBuilder(
            builder: (context, constraints) {
              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: AppContentContainer(
                        maxWidth: AppContentWidth.narrow,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'My Bookings',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (kIsWeb)
                              IconButton(
                                tooltip: 'Refresh',
                                onPressed: () => _refresh(ref),
                                icon: const Icon(Icons.refresh),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (sections.upcoming.isNotEmpty)
                      ..._sectionSlivers(
                        context,
                        title: 'Upcoming',
                        bookings: sections.upcoming,
                        ref: ref,
                      ),
                    if (sections.history.isNotEmpty)
                      ..._sectionSlivers(
                        context,
                        title: 'History',
                        bookings: sections.history,
                        ref: ref,
                        muted: true,
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _sectionSlivers(
    BuildContext context, {
    required String title,
    required List<BookingModel> bookings,
    required WidgetRef ref,
    bool muted = false,
  }) {
    return [
      SliverToBoxAdapter(
        child: AppContentContainer(
          maxWidth: AppContentWidth.narrow,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
      SliverToBoxAdapter(
        child: AppContentContainer(
          maxWidth: AppContentWidth.narrow,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            children: [
              for (var i = 0; i < bookings.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OwnerBookingCard(
                    booking: bookings[i],
                    muted: muted,
                    onUpdated: () async {
                      ref.invalidate(currentOwnerBookingsProvider);
                      ref.invalidate(bookingByIdProvider(bookings[i].id));
                      await ref.read(currentOwnerBookingsProvider.future);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _EmptyBookingsState extends StatelessWidget {
  const _EmptyBookingsState({
    required this.onRefresh,
    required this.onFindService,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback onFindService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                maxWidth: 480,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (kIsWeb)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Refresh',
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.55,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy_outlined,
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You have no bookings yet.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use PawPal’s AI Service Finder to find the right service '
                      'and request a booking with a provider.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Find a Service',
                      onPressed: onFindService,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OwnerBookingCard extends ConsumerStatefulWidget {
  const _OwnerBookingCard({
    required this.booking,
    required this.onUpdated,
    this.muted = false,
  });

  final BookingModel booking;
  final Future<void> Function() onUpdated;
  final bool muted;

  @override
  ConsumerState<_OwnerBookingCard> createState() => _OwnerBookingCardState();
}

class _OwnerBookingCardState extends ConsumerState<_OwnerBookingCard> {
  bool get _canCancel => canOwnerCancelBooking(widget.booking);

  bool get _canPayByCard => canOwnerDemoPayBooking(widget.booking);

  Future<void> _confirmCancel() async {
    if (!_canCancel) return;

    final serviceName = widget.booking.serviceNameSnapshot;
    final bookingId = widget.booking.id;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var dialogBusy = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> confirm() async {
              if (dialogBusy) return;
              setDialogState(() {
                dialogBusy = true;
                dialogError = null;
              });

              try {
                await ref
                    .read(bookingRepositoryProvider)
                    .cancelBooking(bookingId);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                await widget.onUpdated();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$serviceName booking was cancelled.'),
                  ),
                );
              } on BookingException catch (error) {
                if (!context.mounted) return;
                setDialogState(() {
                  dialogBusy = false;
                  dialogError = error.message;
                });
              } catch (_) {
                if (!context.mounted) return;
                setDialogState(() {
                  dialogBusy = false;
                  dialogError =
                      'Unable to cancel this booking. Please try again.';
                });
              }
            }

            return PopScope(
              canPop: !dialogBusy,
              child: AlertDialog(
                title: const Text('Cancel booking?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'This booking request for $serviceName will be cancelled. '
                      'This action cannot be undone.',
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: dialogBusy
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Keep Booking'),
                  ),
                  FilledButton(
                    key: const Key('confirm_cancel_booking'),
                    onPressed: dialogBusy ? null : confirm,
                    child: dialogBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cancel Booking'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booking = widget.booking;
    final localStart = booking.requestedStart.toLocal();
    final duration = booking.estimatedDurationMinutes;
    final notes = booking.ownerNotes?.trim();
    final showPayment =
        booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.accepted ||
        booking.paymentStatus != BookingPaymentStatus.unpaid;

    return Opacity(
      opacity: widget.muted ? 0.88 : 1,
      child: Card(
        elevation: widget.muted ? 0 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: widget.muted
              ? BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                booking.serviceNameSnapshot,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(booking.petNameSnapshot, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatBookingDate(localStart),
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          formatBookingTime(localStart),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                SitterServicesScreen.formatPrice(booking.priceSnapshot),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (duration != null) ...[
                const SizedBox(height: 4),
                Text(
                  SitterServicesScreen.formatDuration(duration),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  bookingStatusChip(theme, booking.status),
                  if (showPayment)
                    bookingPaymentStatusChip(theme, booking.paymentStatus),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                bookingStatusDescription(booking.status),
                style: theme.textTheme.bodySmall,
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '“$notes”',
                  style: theme.textTheme.bodyMedium,
                  softWrap: true,
                ),
              ],
              if (_canPayByCard || _canCancel) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_canPayByCard)
                      FilledButton(
                        key: Key('pay_by_card_booking_${booking.id}'),
                        onPressed: () =>
                            context.push(AppRoutes.bookingPayment(booking.id)),
                        child: const Text('Pay by Card'),
                      ),
                    if (_canCancel)
                      OutlinedButton(
                        key: Key('cancel_booking_${booking.id}'),
                        onPressed: _confirmCancel,
                        child: const Text('Cancel Booking'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared booking-status chip for owner and sitter booking cards.
Widget bookingStatusChip(ThemeData theme, BookingStatus status) {
  final Color backgroundColor;
  final Color labelColor;

  switch (status) {
    case BookingStatus.pending:
      backgroundColor = AppColors.warningContainer;
      labelColor = AppColors.onWarningContainer;
    case BookingStatus.accepted:
    case BookingStatus.completed:
      backgroundColor = AppColors.successContainer;
      labelColor = AppColors.onSuccessContainer;
    case BookingStatus.declined:
      backgroundColor = AppColors.errorContainer;
      labelColor = AppColors.onErrorContainer;
    case BookingStatus.cancelled:
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      labelColor = theme.colorScheme.onSurfaceVariant;
  }

  return Chip(
    label: Text(status.displayName),
    visualDensity: VisualDensity.compact,
    backgroundColor: backgroundColor,
    side: BorderSide.none,
    labelStyle: theme.textTheme.labelLarge?.copyWith(color: labelColor),
  );
}

/// Shared payment-status chip for owner and sitter booking cards.
Widget bookingPaymentStatusChip(ThemeData theme, BookingPaymentStatus status) {
  final isDemoPaid = status == BookingPaymentStatus.demoPaid;
  return Chip(
    label: Text(status.displayName),
    visualDensity: VisualDensity.compact,
    backgroundColor: isDemoPaid ? theme.colorScheme.primaryContainer : null,
    labelStyle: isDemoPaid
        ? theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          )
        : null,
  );
}

/// Split owner bookings into Upcoming and History sections.
@visibleForTesting
OwnerBookingSections partitionOwnerBookings(
  List<BookingModel> bookings, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final upcoming = <BookingModel>[];
  final history = <BookingModel>[];

  for (final booking in bookings) {
    if (isUpcomingOwnerBooking(booking, now: clock)) {
      upcoming.add(booking);
    } else {
      history.add(booking);
    }
  }

  upcoming.sort((a, b) => a.requestedStart.compareTo(b.requestedStart));
  history.sort((a, b) => b.requestedStart.compareTo(a.requestedStart));

  return OwnerBookingSections(upcoming: upcoming, history: history);
}

/// Whether a booking belongs in the Upcoming section.
@visibleForTesting
bool isUpcomingOwnerBooking(BookingModel booking, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final isOpenStatus =
      booking.status == BookingStatus.pending ||
      booking.status == BookingStatus.accepted;
  return isOpenStatus && booking.requestedStart.toLocal().isAfter(clock);
}

/// Whether the owner may cancel this booking from the UI.
@visibleForTesting
bool canOwnerCancelBooking(BookingModel booking) {
  return booking.status == BookingStatus.pending ||
      booking.status == BookingStatus.accepted;
}

/// Whether the owner may run the simulated demo payment action.
@visibleForTesting
bool canOwnerDemoPayBooking(BookingModel booking) {
  return booking.status == BookingStatus.accepted &&
      booking.paymentStatus == BookingPaymentStatus.unpaid;
}

/// Short status explanation shown under the status chip.
@visibleForTesting
String bookingStatusDescription(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => 'Waiting for sitter response',
    BookingStatus.accepted => 'Booking accepted',
    BookingStatus.declined => 'Booking declined',
    BookingStatus.cancelled => 'Booking cancelled',
    BookingStatus.completed => 'Completed',
  };
}

/// Local time label without installing a package.
String formatBookingTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final isPm = hour >= 12;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$minute ${isPm ? 'PM' : 'AM'}';
}

@visibleForTesting
class OwnerBookingSections {
  const OwnerBookingSections({required this.upcoming, required this.history});

  final List<BookingModel> upcoming;
  final List<BookingModel> history;
}
