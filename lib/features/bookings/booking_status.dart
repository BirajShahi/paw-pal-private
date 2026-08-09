/// Booking lifecycle status from `public.bookings.status`.
enum BookingStatus {
  pending,
  accepted,
  declined,
  cancelled,
  completed;

  String get databaseValue => switch (this) {
    BookingStatus.pending => 'pending',
    BookingStatus.accepted => 'accepted',
    BookingStatus.declined => 'declined',
    BookingStatus.cancelled => 'cancelled',
    BookingStatus.completed => 'completed',
  };

  String get displayName => switch (this) {
    BookingStatus.pending => 'Pending',
    BookingStatus.accepted => 'Accepted',
    BookingStatus.declined => 'Declined',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.completed => 'Completed',
  };

  static BookingStatus fromDatabaseValue(String value) {
    return switch (value) {
      'pending' => BookingStatus.pending,
      'accepted' => BookingStatus.accepted,
      'declined' => BookingStatus.declined,
      'cancelled' => BookingStatus.cancelled,
      'completed' => BookingStatus.completed,
      _ => throw FormatException('Unsupported booking status: $value'),
    };
  }
}
