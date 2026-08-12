/// Client payload for creating a row in `public.bookings`.
///
/// Snapshots (including pet care notes), sitter assignment, status and
/// payment status are set by the database trigger — not by the Flutter client.
class CreateBookingRequest {
  CreateBookingRequest({
    required String petId,
    required String sitterServiceId,
    required DateTime requestedStart,
    String? ownerNotes,
  }) : petId = _requireNonBlank(petId, 'Pet id'),
       sitterServiceId = _requireNonBlank(sitterServiceId, 'Sitter service id'),
       requestedStart = _requireFuture(requestedStart),
       ownerNotes = _normaliseNotes(ownerNotes);

  final String petId;
  final String sitterServiceId;
  final DateTime requestedStart;
  final String? ownerNotes;

  Map<String, dynamic> toInsertMap({required String ownerId}) {
    return {
      'owner_id': ownerId,
      'pet_id': petId,
      'sitter_service_id': sitterServiceId,
      'requested_start': requestedStart.toUtc().toIso8601String(),
      'owner_notes': ownerNotes,
    };
  }

  static String _requireNonBlank(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('$label is required.');
    }
    return trimmed;
  }

  static DateTime _requireFuture(DateTime requestedStart) {
    if (!requestedStart.toUtc().isAfter(DateTime.now().toUtc())) {
      throw const FormatException(
        'Please select a future booking date and time.',
      );
    }
    return requestedStart;
  }

  static String? _normaliseNotes(String? ownerNotes) {
    if (ownerNotes == null) return null;
    final trimmed = ownerNotes.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 1000) {
      throw const FormatException(
        'Owner notes may contain up to 1000 characters.',
      );
    }
    return trimmed;
  }
}
