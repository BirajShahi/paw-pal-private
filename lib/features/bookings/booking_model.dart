import 'booking_payment_status.dart';
import 'booking_status.dart';

/// Row from `public.bookings`.
class BookingModel {
  const BookingModel({
    required this.id,
    required this.ownerId,
    this.petId,
    required this.sitterId,
    this.sitterServiceId,
    required this.petNameSnapshot,
    required this.serviceCodeSnapshot,
    required this.serviceNameSnapshot,
    required this.priceSnapshot,
    this.estimatedDurationMinutes,
    required this.requestedStart,
    this.ownerNotes,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String? petId;
  final String sitterId;
  final String? sitterServiceId;
  final String petNameSnapshot;
  final String serviceCodeSnapshot;
  final String serviceNameSnapshot;
  final double priceSnapshot;
  final int? estimatedDurationMinutes;
  final DateTime requestedStart;
  final String? ownerNotes;
  final BookingStatus status;
  final BookingPaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] as String?)?.trim() ?? '';
    final ownerId = (map['owner_id'] as String?)?.trim() ?? '';
    final petIdRaw = (map['pet_id'] as String?)?.trim();
    final sitterId = (map['sitter_id'] as String?)?.trim() ?? '';
    final sitterServiceIdRaw = (map['sitter_service_id'] as String?)?.trim();
    final petNameSnapshot = (map['pet_name_snapshot'] as String?)?.trim() ?? '';
    final serviceCodeSnapshot =
        (map['service_code_snapshot'] as String?)?.trim() ?? '';
    final serviceNameSnapshot =
        (map['service_name_snapshot'] as String?)?.trim() ?? '';
    final price = _toDouble(map['price_snapshot']);
    final duration = _toInt(map['estimated_duration_minutes']);
    final requestedStart = _parseDateTime(map['requested_start']);
    final ownerNotes = _trimOrNull(map['owner_notes'] as String?);
    final statusRaw = map['status'] as String?;
    final paymentStatusRaw = map['payment_status'] as String?;
    final createdAt = _parseDateTime(map['created_at']);
    final updatedAt = _parseDateTime(map['updated_at']);

    if (id.isEmpty) {
      throw const FormatException('Booking id is missing.');
    }
    if (ownerId.isEmpty) {
      throw const FormatException('Booking owner id is missing.');
    }
    if (sitterId.isEmpty) {
      throw const FormatException('Booking sitter id is missing.');
    }
    if (petNameSnapshot.isEmpty) {
      throw const FormatException('Booking pet name snapshot is missing.');
    }
    if (serviceCodeSnapshot.isEmpty) {
      throw const FormatException('Booking service code snapshot is missing.');
    }
    if (serviceNameSnapshot.isEmpty) {
      throw const FormatException('Booking service name snapshot is missing.');
    }
    if (price == null) {
      throw const FormatException('Booking price snapshot is missing.');
    }
    if (price <= 0 || price > 1000) {
      throw const FormatException(
        'Booking price must be greater than 0 and at most 1000.',
      );
    }
    if (duration != null && (duration < 15 || duration > 1440)) {
      throw const FormatException(
        'Booking duration must be between 15 and 1440 minutes.',
      );
    }
    if (requestedStart == null) {
      throw const FormatException('Booking requested start is missing.');
    }
    if (statusRaw == null || statusRaw.trim().isEmpty) {
      throw const FormatException('Booking status is missing.');
    }
    if (paymentStatusRaw == null || paymentStatusRaw.trim().isEmpty) {
      throw const FormatException('Booking payment status is missing.');
    }
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('Booking timestamps are missing.');
    }

    final petId = (petIdRaw == null || petIdRaw.isEmpty) ? null : petIdRaw;
    final sitterServiceId =
        (sitterServiceIdRaw == null || sitterServiceIdRaw.isEmpty)
        ? null
        : sitterServiceIdRaw;

    return BookingModel(
      id: id,
      ownerId: ownerId,
      petId: petId,
      sitterId: sitterId,
      sitterServiceId: sitterServiceId,
      petNameSnapshot: petNameSnapshot,
      serviceCodeSnapshot: serviceCodeSnapshot,
      serviceNameSnapshot: serviceNameSnapshot,
      priceSnapshot: price,
      estimatedDurationMinutes: duration,
      requestedStart: requestedStart,
      ownerNotes: ownerNotes,
      status: BookingStatus.fromDatabaseValue(statusRaw.trim()),
      paymentStatus: BookingPaymentStatus.fromDatabaseValue(
        paymentStatusRaw.trim(),
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
