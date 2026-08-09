import 'package:supabase_flutter/supabase_flutter.dart';

import 'booking_model.dart';
import 'booking_status.dart';
import 'create_booking_request.dart';

/// Thrown when a booking cannot be loaded or updated.
class BookingException implements Exception {
  const BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _bookingSelect =
    'id, owner_id, pet_id, sitter_id, sitter_service_id, '
    'pet_name_snapshot, service_code_snapshot, service_name_snapshot, '
    'price_snapshot, estimated_duration_minutes, requested_start, '
    'owner_notes, status, payment_status, created_at, updated_at';

/// Supabase access for `public.bookings`.
class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  Future<BookingModel> createBooking(CreateBookingRequest request) async {
    final userId = _requireUserId();

    try {
      final row = await _client
          .from('bookings')
          .insert(request.toInsertMap(ownerId: userId))
          .select(_bookingSelect)
          .single();

      return BookingModel.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      throw BookingException(_mapCreateError(error));
    } on FormatException catch (error) {
      throw BookingException(error.message);
    }
  }

  Future<List<BookingModel>> getCurrentOwnerBookings() async {
    final userId = _requireUserId();

    final rows = await _client
        .from('bookings')
        .select(_bookingSelect)
        .eq('owner_id', userId)
        .order('requested_start', ascending: true);

    return [
      for (final row in rows as List<dynamic>)
        BookingModel.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<BookingModel>> getCurrentSitterBookings() async {
    final userId = _requireUserId();

    final rows = await _client
        .from('bookings')
        .select(_bookingSelect)
        .eq('sitter_id', userId)
        .order('requested_start', ascending: true);

    return [
      for (final row in rows as List<dynamic>)
        BookingModel.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<BookingModel> getBookingById(String bookingId) async {
    final userId = _requireUserId();
    final trimmedId = bookingId.trim();
    if (trimmedId.isEmpty) {
      throw const BookingException('Booking id is required.');
    }

    final row = await _client
        .from('bookings')
        .select(_bookingSelect)
        .eq('id', trimmedId)
        .or('owner_id.eq.$userId,sitter_id.eq.$userId')
        .maybeSingle();

    if (row == null) {
      throw const BookingException('This booking is unavailable.');
    }

    try {
      return BookingModel.fromMap(Map<String, dynamic>.from(row));
    } on FormatException catch (error) {
      throw BookingException(error.message);
    }
  }

  Future<BookingModel> cancelBooking(String bookingId) async {
    final userId = _requireUserId();
    final trimmedId = bookingId.trim();
    if (trimmedId.isEmpty) {
      throw const BookingException('Booking id is required.');
    }

    return _updateStatus(
      bookingId: trimmedId,
      status: BookingStatus.cancelled,
      roleColumn: 'owner_id',
      userId: userId,
    );
  }

  Future<BookingModel> acceptBooking(String bookingId) async {
    final userId = _requireUserId();
    final trimmedId = bookingId.trim();
    if (trimmedId.isEmpty) {
      throw const BookingException('Booking id is required.');
    }

    return _updateStatus(
      bookingId: trimmedId,
      status: BookingStatus.accepted,
      roleColumn: 'sitter_id',
      userId: userId,
    );
  }

  Future<BookingModel> declineBooking(String bookingId) async {
    final userId = _requireUserId();
    final trimmedId = bookingId.trim();
    if (trimmedId.isEmpty) {
      throw const BookingException('Booking id is required.');
    }

    return _updateStatus(
      bookingId: trimmedId,
      status: BookingStatus.declined,
      roleColumn: 'sitter_id',
      userId: userId,
    );
  }

  Future<BookingModel> completeBooking(String bookingId) async {
    final userId = _requireUserId();
    final trimmedId = bookingId.trim();
    if (trimmedId.isEmpty) {
      throw const BookingException('Booking id is required.');
    }

    return _updateStatus(
      bookingId: trimmedId,
      status: BookingStatus.completed,
      roleColumn: 'sitter_id',
      userId: userId,
    );
  }

  /// Simulated owner payment via `demo_pay_booking` RPC.
  ///
  /// Does not process real money and never updates payment_status directly.
  Future<BookingModel> demoPayBooking(String bookingId) async {
    _requireUserId();
    final trimmedId = bookingId.trim();
    if (trimmedId.isEmpty) {
      throw const BookingException('Booking id is required.');
    }

    try {
      final row = await _client.rpc(
        'demo_pay_booking',
        params: {'p_booking_id': trimmedId},
      );

      final map = _asBookingMap(row);
      if (map == null) {
        throw const BookingException('This booking is unavailable.');
      }

      return BookingModel.fromMap(map);
    } on PostgrestException catch (error) {
      throw BookingException(_mapDemoPayError(error));
    } on FormatException catch (error) {
      throw BookingException(error.message);
    }
  }

  static Map<String, dynamic>? _asBookingMap(Object? row) {
    if (row is Map<String, dynamic>) {
      return row;
    }
    if (row is Map) {
      return Map<String, dynamic>.from(row);
    }
    if (row is List && row.isNotEmpty) {
      final first = row.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  Future<BookingModel> _updateStatus({
    required String bookingId,
    required BookingStatus status,
    required String roleColumn,
    required String userId,
  }) async {
    try {
      final row = await _client
          .from('bookings')
          .update({'status': status.databaseValue})
          .eq('id', bookingId)
          .eq(roleColumn, userId)
          .select(_bookingSelect)
          .maybeSingle();

      if (row == null) {
        throw const BookingException('This booking is unavailable.');
      }

      return BookingModel.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      throw BookingException(_mapUpdateError(error));
    } on FormatException catch (error) {
      throw BookingException(error.message);
    }
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const BookingException(
        'You are not signed in. Please log in again.',
      );
    }
    return user.id;
  }

  static String _mapCreateError(PostgrestException error) {
    final message = error.message.toLowerCase();

    if (message.contains('future') || message.contains('in the future')) {
      return 'Please select a future booking date and time.';
    }
    if (message.contains('pet is unavailable') ||
        message.contains('pet must be selected')) {
      return 'The selected pet is no longer available.';
    }
    if (message.contains('service offering is unavailable') ||
        message.contains('sitter service must be selected')) {
      return 'The selected service is no longer available.';
    }
    if (message.contains('only owner accounts') ||
        message.contains('owner accounts can create')) {
      return 'Only pet-owner accounts can create bookings.';
    }

    return 'Unable to create this booking. Please try again.';
  }

  static String _mapUpdateError(PostgrestException error) {
    final message = error.message.toLowerCase();

    if (message.contains('status change') ||
        message.contains('cannot be changed') ||
        message.contains('permission')) {
      return 'This booking status change is not allowed.';
    }

    return 'Unable to update this booking. Please try again.';
  }

  static String _mapDemoPayError(PostgrestException error) {
    final message = error.message.toLowerCase();

    if (message.contains('already been demo paid') ||
        message.contains('already been demo_paid')) {
      return 'This booking has already been demo paid.';
    }
    if (message.contains('already been demo refunded') ||
        message.contains('already been refunded')) {
      return 'This booking has already been refunded.';
    }
    if (message.contains('only accepted bookings')) {
      return 'Only accepted bookings can be demo paid.';
    }
    if (message.contains('unavailable')) {
      return 'This booking is unavailable.';
    }

    return 'Unable to complete the demo payment. Please try again.';
  }
}
