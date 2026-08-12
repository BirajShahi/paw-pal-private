import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/features/bookings/booking_model.dart';
import 'package:paw_pal/features/bookings/booking_payment_status.dart';
import 'package:paw_pal/features/bookings/booking_status.dart';
import 'package:paw_pal/features/bookings/create_booking_request.dart';

void main() {
  Map<String, dynamic> bookingMap({
    Object? id = 'booking-1',
    Object? ownerId = 'owner-1',
    Object? petId = 'pet-1',
    Object? sitterId = 'sitter-1',
    Object? sitterServiceId = 'offer-1',
    Object? petNameSnapshot = 'Buddy',
    Object? serviceCodeSnapshot = 'dog_walk',
    Object? serviceNameSnapshot = 'Dog Walking',
    Object? priceSnapshot = 35.5,
    Object? estimatedDurationMinutes = 60,
    Object? requestedStart = '2026-08-15T10:00:00Z',
    Object? ownerNotes = 'Please use the side gate.',
    Object? petMedicalNotesSnapshot,
    Object? petBehaviourNotesSnapshot,
    Object? petCareNotesSnapshot,
    Object? status = 'pending',
    Object? paymentStatus = 'unpaid',
    Object? createdAt = '2026-08-01T09:00:00Z',
    Object? updatedAt = '2026-08-01T09:00:00Z',
  }) {
    return {
      'id': id,
      'owner_id': ownerId,
      'pet_id': petId,
      'sitter_id': sitterId,
      'sitter_service_id': sitterServiceId,
      'pet_name_snapshot': petNameSnapshot,
      'pet_medical_notes_snapshot': petMedicalNotesSnapshot,
      'pet_behaviour_notes_snapshot': petBehaviourNotesSnapshot,
      'pet_care_notes_snapshot': petCareNotesSnapshot,
      'service_code_snapshot': serviceCodeSnapshot,
      'service_name_snapshot': serviceNameSnapshot,
      'price_snapshot': priceSnapshot,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'requested_start': requestedStart,
      'owner_notes': ownerNotes,
      'status': status,
      'payment_status': paymentStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  group('BookingStatus', () {
    test('maps database values and display names', () {
      expect(BookingStatus.fromDatabaseValue('pending'), BookingStatus.pending);
      expect(
        BookingStatus.fromDatabaseValue('accepted'),
        BookingStatus.accepted,
      );
      expect(
        BookingStatus.fromDatabaseValue('declined'),
        BookingStatus.declined,
      );
      expect(
        BookingStatus.fromDatabaseValue('cancelled'),
        BookingStatus.cancelled,
      );
      expect(
        BookingStatus.fromDatabaseValue('completed'),
        BookingStatus.completed,
      );

      expect(BookingStatus.pending.databaseValue, 'pending');
      expect(BookingStatus.accepted.databaseValue, 'accepted');
      expect(BookingStatus.declined.databaseValue, 'declined');
      expect(BookingStatus.cancelled.databaseValue, 'cancelled');
      expect(BookingStatus.completed.databaseValue, 'completed');

      expect(BookingStatus.pending.displayName, 'Pending');
      expect(BookingStatus.accepted.displayName, 'Accepted');
      expect(BookingStatus.declined.displayName, 'Declined');
      expect(BookingStatus.cancelled.displayName, 'Cancelled');
      expect(BookingStatus.completed.displayName, 'Completed');
    });

    test('rejects unsupported values', () {
      expect(
        () => BookingStatus.fromDatabaseValue('unknown'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BookingPaymentStatus', () {
    test('maps database values and display names', () {
      expect(
        BookingPaymentStatus.fromDatabaseValue('unpaid'),
        BookingPaymentStatus.unpaid,
      );
      expect(
        BookingPaymentStatus.fromDatabaseValue('demo_paid'),
        BookingPaymentStatus.demoPaid,
      );
      expect(
        BookingPaymentStatus.fromDatabaseValue('demo_refunded'),
        BookingPaymentStatus.demoRefunded,
      );

      expect(BookingPaymentStatus.unpaid.databaseValue, 'unpaid');
      expect(BookingPaymentStatus.demoPaid.databaseValue, 'demo_paid');
      expect(BookingPaymentStatus.demoRefunded.databaseValue, 'demo_refunded');

      expect(BookingPaymentStatus.unpaid.displayName, 'Unpaid');
      expect(BookingPaymentStatus.demoPaid.displayName, 'Demo Paid');
      expect(BookingPaymentStatus.demoRefunded.displayName, 'Demo Refunded');
    });

    test('rejects unsupported values', () {
      expect(
        () => BookingPaymentStatus.fromDatabaseValue('paid'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BookingModel.fromMap', () {
    test('maps a complete booking row', () {
      final booking = BookingModel.fromMap(bookingMap());

      expect(booking.id, 'booking-1');
      expect(booking.ownerId, 'owner-1');
      expect(booking.petId, 'pet-1');
      expect(booking.sitterId, 'sitter-1');
      expect(booking.sitterServiceId, 'offer-1');
      expect(booking.petNameSnapshot, 'Buddy');
      expect(booking.serviceCodeSnapshot, 'dog_walk');
      expect(booking.serviceNameSnapshot, 'Dog Walking');
      expect(booking.priceSnapshot, 35.5);
      expect(booking.estimatedDurationMinutes, 60);
      expect(
        booking.requestedStart.toUtc().toIso8601String(),
        '2026-08-15T10:00:00.000Z',
      );
      expect(booking.ownerNotes, 'Please use the side gate.');
      expect(booking.petMedicalNotesSnapshot, isNull);
      expect(booking.petBehaviourNotesSnapshot, isNull);
      expect(booking.petCareNotesSnapshot, isNull);
      expect(booking.status, BookingStatus.pending);
      expect(booking.paymentStatus, BookingPaymentStatus.unpaid);
    });

    test('maps pet care note snapshots from the booking row', () {
      final booking = BookingModel.fromMap(
        bookingMap(
          petMedicalNotesSnapshot: '  Allergic to chicken.  ',
          petBehaviourNotesSnapshot: 'Nervous around large dogs.',
          petCareNotesSnapshot: 'Needs fresh water available at all times.',
        ),
      );

      expect(booking.petMedicalNotesSnapshot, 'Allergic to chicken.');
      expect(booking.petBehaviourNotesSnapshot, 'Nervous around large dogs.');
      expect(
        booking.petCareNotesSnapshot,
        'Needs fresh water available at all times.',
      );
    });

    test('converts blank pet care note snapshots to null', () {
      final booking = BookingModel.fromMap(
        bookingMap(
          petMedicalNotesSnapshot: '   ',
          petBehaviourNotesSnapshot: '',
          petCareNotesSnapshot: null,
        ),
      );

      expect(booking.petMedicalNotesSnapshot, isNull);
      expect(booking.petBehaviourNotesSnapshot, isNull);
      expect(booking.petCareNotesSnapshot, isNull);
    });

    test('converts numeric price with num.toDouble()', () {
      final fromInt = BookingModel.fromMap(bookingMap(priceSnapshot: 40));
      final fromDouble = BookingModel.fromMap(bookingMap(priceSnapshot: 40.25));

      expect(fromInt.priceSnapshot, 40.0);
      expect(fromDouble.priceSnapshot, 40.25);
    });

    test('allows null petId and sitterServiceId', () {
      final booking = BookingModel.fromMap(
        bookingMap(petId: null, sitterServiceId: null),
      );

      expect(booking.petId, isNull);
      expect(booking.sitterServiceId, isNull);
    });

    test('converts blank owner notes to null', () {
      final booking = BookingModel.fromMap(bookingMap(ownerNotes: '   '));

      expect(booking.ownerNotes, isNull);
    });

    test('rejects invalid price', () {
      expect(
        () => BookingModel.fromMap(bookingMap(priceSnapshot: 0)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BookingModel.fromMap(bookingMap(priceSnapshot: -5)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BookingModel.fromMap(bookingMap(priceSnapshot: 1000.01)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid duration', () {
      expect(
        () => BookingModel.fromMap(bookingMap(estimatedDurationMinutes: 14)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BookingModel.fromMap(bookingMap(estimatedDurationMinutes: 1441)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported booking status', () {
      expect(
        () => BookingModel.fromMap(bookingMap(status: 'archived')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported payment status', () {
      expect(
        () => BookingModel.fromMap(bookingMap(paymentStatus: 'paid')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CreateBookingRequest', () {
    test('validates and normalises a valid request', () {
      final start = DateTime.now().toUtc().add(const Duration(days: 2));
      final request = CreateBookingRequest(
        petId: '  pet-1  ',
        sitterServiceId: '  offer-1  ',
        requestedStart: start,
        ownerNotes: '  Please knock  ',
      );

      expect(request.petId, 'pet-1');
      expect(request.sitterServiceId, 'offer-1');
      expect(request.ownerNotes, 'Please knock');

      final insert = request.toInsertMap(ownerId: 'owner-1');
      expect(
        insert.keys,
        unorderedEquals([
          'owner_id',
          'pet_id',
          'sitter_service_id',
          'requested_start',
          'owner_notes',
        ]),
      );
      expect(insert.containsKey('sitter_id'), isFalse);
      expect(insert.containsKey('pet_name_snapshot'), isFalse);
      expect(insert.containsKey('pet_medical_notes_snapshot'), isFalse);
      expect(insert.containsKey('pet_behaviour_notes_snapshot'), isFalse);
      expect(insert.containsKey('pet_care_notes_snapshot'), isFalse);
      expect(insert.containsKey('service_code_snapshot'), isFalse);
      expect(insert.containsKey('service_name_snapshot'), isFalse);
      expect(insert.containsKey('price_snapshot'), isFalse);
      expect(insert.containsKey('estimated_duration_minutes'), isFalse);
      expect(insert.containsKey('status'), isFalse);
      expect(insert.containsKey('payment_status'), isFalse);
    });

    test('rejects blank ids', () {
      final start = DateTime.now().toUtc().add(const Duration(days: 1));

      expect(
        () => CreateBookingRequest(
          petId: ' ',
          sitterServiceId: 'offer-1',
          requestedStart: start,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CreateBookingRequest(
          petId: 'pet-1',
          sitterServiceId: '',
          requestedStart: start,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects past requestedStart', () {
      expect(
        () => CreateBookingRequest(
          petId: 'pet-1',
          sitterServiceId: 'offer-1',
          requestedStart: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('converts blank ownerNotes to null and enforces max length', () {
      final start = DateTime.now().toUtc().add(const Duration(days: 1));

      final blankNotes = CreateBookingRequest(
        petId: 'pet-1',
        sitterServiceId: 'offer-1',
        requestedStart: start,
        ownerNotes: '   ',
      );
      expect(blankNotes.ownerNotes, isNull);

      expect(
        () => CreateBookingRequest(
          petId: 'pet-1',
          sitterServiceId: 'offer-1',
          requestedStart: start,
          ownerNotes: 'a' * 1001,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
