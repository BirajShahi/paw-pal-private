import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'booking_model.dart';
import 'booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(Supabase.instance.client);
});

/// Bookings owned by the signed-in pet owner. Refresh with `ref.invalidate`.
final currentOwnerBookingsProvider = FutureProvider<List<BookingModel>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const BookingException('You are not signed in. Please log in again.');
  }

  return ref.read(bookingRepositoryProvider).getCurrentOwnerBookings();
});

/// Bookings assigned to the signed-in sitter. Refresh with `ref.invalidate`.
final currentSitterBookingsProvider = FutureProvider<List<BookingModel>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const BookingException('You are not signed in. Please log in again.');
  }

  return ref.read(bookingRepositoryProvider).getCurrentSitterBookings();
});

/// One booking by ID for the signed-in owner or sitter.
/// Refresh with `ref.invalidate`.
final bookingByIdProvider = FutureProvider.family<BookingModel, String>((
  ref,
  bookingId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const BookingException('You are not signed in. Please log in again.');
  }

  return ref.read(bookingRepositoryProvider).getBookingById(bookingId);
});
