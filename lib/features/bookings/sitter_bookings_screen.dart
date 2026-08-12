import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../services/sitter_services_screen.dart';
import 'booking_model.dart';
import 'booking_payment_status.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';
import 'booking_status.dart';
import 'create_booking_screen.dart';
import 'owner_bookings_screen.dart';

/// Sitter list of assigned bookings for `/sitter-bookings`.
class SitterBookingsScreen extends ConsumerWidget {
  const SitterBookingsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentSitterBookingsProvider);
    await ref.read(currentSitterBookingsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(currentSitterBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: appBackLeading(
          context,
          fallbackRoute: AppRoutes.sitterDashboard,
        ),
        title: const Text('Booking Requests'),
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: bookingsAsync.when(
          loading: () =>
              const LoadingIndicator(message: 'Loading booking requests…'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorMessage(
                message: error is BookingException
                    ? error.message
                    : error.toString(),
                onRetry: () => ref.invalidate(currentSitterBookingsProvider),
              ),
            ),
          ),
          data: (bookings) {
            if (bookings.isEmpty) {
              return _EmptySitterBookingsState(onRefresh: () => _refresh(ref));
            }

            final sections = partitionSitterBookings(bookings);

            return LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (sections.requests.isNotEmpty)
                        ..._sectionSlivers(
                          context,
                          title: 'Requests',
                          bookings: sections.requests,
                          ref: ref,
                          highlightSection: true,
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
      ),
    );
  }

  List<Widget> _sectionSlivers(
    BuildContext context, {
    required String title,
    required List<BookingModel> bookings,
    required WidgetRef ref,
    bool highlightSection = false,
    bool muted = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final cards = Column(
      children: [
        for (var i = 0; i < bookings.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SitterBookingCard(
              booking: bookings[i],
              muted: muted,
              onStatusChanged: () async {
                ref.invalidate(currentSitterBookingsProvider);
                ref.invalidate(bookingByIdProvider(bookings[i].id));
                await ref.read(currentSitterBookingsProvider.future);
              },
              onStaleFailure: () async {
                ref.invalidate(currentSitterBookingsProvider);
                await ref.read(currentSitterBookingsProvider.future);
              },
            ),
          ),
      ],
    );

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
          child: highlightSection
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: cards,
                )
              : cards,
        ),
      ),
    ];
  }
}

class _EmptySitterBookingsState extends StatelessWidget {
  const _EmptySitterBookingsState({required this.onRefresh});

  final Future<void> Function() onRefresh;

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
                        Icons.inbox_outlined,
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No booking requests yet.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When pet owners request one of your services, the '
                      'booking will appear here.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
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

class _SitterBookingCard extends ConsumerStatefulWidget {
  const _SitterBookingCard({
    required this.booking,
    required this.onStatusChanged,
    required this.onStaleFailure,
    this.muted = false,
  });

  final BookingModel booking;
  final Future<void> Function() onStatusChanged;
  final Future<void> Function() onStaleFailure;
  final bool muted;

  @override
  ConsumerState<_SitterBookingCard> createState() => _SitterBookingCardState();
}

class _SitterBookingCardState extends ConsumerState<_SitterBookingCard> {
  Future<void> _runStatusAction({
    required String title,
    required String message,
    required String dismissLabel,
    required String confirmLabel,
    required Key confirmKey,
    required Future<BookingModel> Function() action,
    required String successMessage,
  }) async {
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
                await action();

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                await widget.onStatusChanged();
                messenger.showSnackBar(SnackBar(content: Text(successMessage)));
              } on BookingException catch (error) {
                if (!context.mounted) return;
                setDialogState(() {
                  dialogBusy = false;
                  dialogError = error.message;
                });
                await widget.onStaleFailure();
              } catch (_) {
                if (!context.mounted) return;
                setDialogState(() {
                  dialogBusy = false;
                  dialogError =
                      'Unable to update this booking. Please try again.';
                });
                await widget.onStaleFailure();
              }
            }

            return PopScope(
              canPop: !dialogBusy,
              child: AlertDialog(
                title: Text(title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(message),
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
                    child: Text(dismissLabel),
                  ),
                  FilledButton(
                    key: confirmKey,
                    onPressed: dialogBusy ? null : confirm,
                    child: dialogBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(confirmLabel),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _accept() {
    final booking = widget.booking;
    final serviceName = booking.serviceNameSnapshot;
    return _runStatusAction(
      title: 'Accept booking?',
      message:
          'You are confirming that you can provide $serviceName at the '
          'requested date and time.',
      dismissLabel: 'Not Yet',
      confirmLabel: 'Accept Booking',
      confirmKey: const Key('confirm_accept_booking'),
      action: () =>
          ref.read(bookingRepositoryProvider).acceptBooking(booking.id),
      successMessage: '$serviceName booking was accepted.',
    );
  }

  Future<void> _decline() {
    final booking = widget.booking;
    final serviceName = booking.serviceNameSnapshot;
    return _runStatusAction(
      title: 'Decline booking?',
      message:
          'This booking request will be declined and the pet owner will see '
          'the updated status.',
      dismissLabel: 'Keep Request',
      confirmLabel: 'Decline Booking',
      confirmKey: const Key('confirm_decline_booking'),
      action: () =>
          ref.read(bookingRepositoryProvider).declineBooking(booking.id),
      successMessage: '$serviceName booking was declined.',
    );
  }

  Future<void> _complete() {
    final booking = widget.booking;
    final serviceName = booking.serviceNameSnapshot;
    return _runStatusAction(
      title: 'Complete booking?',
      message: 'Confirm that $serviceName has been completed.',
      dismissLabel: 'Not Yet',
      confirmLabel: 'Mark Completed',
      confirmKey: const Key('confirm_complete_booking'),
      action: () =>
          ref.read(bookingRepositoryProvider).completeBooking(booking.id),
      successMessage: '$serviceName booking was completed.',
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
    final showPendingActions = canSitterRespondToBooking(booking);
    final showComplete = canSitterCompleteBooking(booking);

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
              Text(
                'Pet: ${booking.petNameSnapshot}',
                style: theme.textTheme.bodyLarge,
              ),
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
              if (bookingHasPetCareInformation(booking)) ...[
                const SizedBox(height: 12),
                _PetCareInformationSection(booking: booking),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Owner notes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '“$notes”',
                  style: theme.textTheme.bodyMedium,
                  softWrap: true,
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
                sitterBookingStatusDescription(booking.status),
                style: theme.textTheme.bodySmall,
              ),
              if (showPendingActions) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: Key('accept_booking_${booking.id}'),
                      onPressed: _accept,
                      child: const Text('Accept Booking'),
                    ),
                    OutlinedButton(
                      key: Key('decline_booking_${booking.id}'),
                      onPressed: _decline,
                      child: const Text('Decline Booking'),
                    ),
                  ],
                ),
              ],
              if (showComplete) ...[
                const SizedBox(height: 16),
                FilledButton(
                  key: Key('complete_booking_${booking.id}'),
                  onPressed: _complete,
                  child: const Text('Mark as Completed'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Owner-provided pet care notes snapped onto the booking.
class _PetCareInformationSection extends StatelessWidget {
  const _PetCareInformationSection({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medical = usefulPetCareNote(booking.petMedicalNotesSnapshot);
    final behaviour = usefulPetCareNote(booking.petBehaviourNotesSnapshot);
    final care = usefulPetCareNote(booking.petCareNotesSnapshot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pet care information', style: theme.textTheme.titleSmall),
        if (medical != null) ...[
          const SizedBox(height: 8),
          _PetCareNoteBlock(
            icon: Icons.health_and_safety_outlined,
            label: 'Medical',
            note: medical,
          ),
        ],
        if (behaviour != null) ...[
          const SizedBox(height: 8),
          _PetCareNoteBlock(
            icon: Icons.pets_outlined,
            label: 'Behaviour',
            note: behaviour,
          ),
        ],
        if (care != null) ...[
          const SizedBox(height: 8),
          _PetCareNoteBlock(
            icon: Icons.info_outline,
            label: 'Care instructions',
            note: care,
          ),
        ],
      ],
    );
  }
}

class _PetCareNoteBlock extends StatelessWidget {
  const _PetCareNoteBlock({
    required this.icon,
    required this.label,
    required this.note,
  });

  final IconData icon;
  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                '“$note”',
                style: theme.textTheme.bodyMedium,
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Split sitter bookings into Requests, Upcoming and History.
@visibleForTesting
SitterBookingSections partitionSitterBookings(
  List<BookingModel> bookings, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final requests = <BookingModel>[];
  final upcoming = <BookingModel>[];
  final history = <BookingModel>[];

  for (final booking in bookings) {
    if (booking.status == BookingStatus.pending) {
      requests.add(booking);
    } else if (isUpcomingSitterBooking(booking, now: clock)) {
      upcoming.add(booking);
    } else {
      history.add(booking);
    }
  }

  requests.sort((a, b) => a.requestedStart.compareTo(b.requestedStart));
  upcoming.sort((a, b) => a.requestedStart.compareTo(b.requestedStart));
  history.sort((a, b) => b.requestedStart.compareTo(a.requestedStart));

  return SitterBookingSections(
    requests: requests,
    upcoming: upcoming,
    history: history,
  );
}

/// Accepted bookings still in the future.
@visibleForTesting
bool isUpcomingSitterBooking(BookingModel booking, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  return booking.status == BookingStatus.accepted &&
      booking.requestedStart.toLocal().isAfter(clock);
}

/// Pending bookings can be accepted or declined.
@visibleForTesting
bool canSitterRespondToBooking(BookingModel booking) {
  return booking.status == BookingStatus.pending;
}

/// Accepted bookings that are not in the future can be completed.
@visibleForTesting
bool canSitterCompleteBooking(BookingModel booking, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  return booking.status == BookingStatus.accepted &&
      !booking.requestedStart.toLocal().isAfter(clock);
}

/// Short status explanation for sitters.
@visibleForTesting
String sitterBookingStatusDescription(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => 'Waiting for your response',
    BookingStatus.accepted => 'You accepted this booking',
    BookingStatus.declined => 'You declined this booking',
    BookingStatus.cancelled => 'Cancelled by the owner',
    BookingStatus.completed => 'Service completed',
  };
}

/// Trims blank owner-provided pet-care snapshot text to null.
@visibleForTesting
String? usefulPetCareNote(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// True when at least one pet-care snapshot has useful text.
@visibleForTesting
bool bookingHasPetCareInformation(BookingModel booking) {
  return usefulPetCareNote(booking.petMedicalNotesSnapshot) != null ||
      usefulPetCareNote(booking.petBehaviourNotesSnapshot) != null ||
      usefulPetCareNote(booking.petCareNotesSnapshot) != null;
}

@visibleForTesting
class SitterBookingSections {
  const SitterBookingSections({
    required this.requests,
    required this.upcoming,
    required this.history,
  });

  final List<BookingModel> requests;
  final List<BookingModel> upcoming;
  final List<BookingModel> history;
}
