/// Demo payment status from `public.bookings.payment_status`.
///
/// This is for demonstration only. No real payment processing is involved.
enum BookingPaymentStatus {
  unpaid,
  demoPaid,
  demoRefunded;

  String get databaseValue => switch (this) {
    BookingPaymentStatus.unpaid => 'unpaid',
    BookingPaymentStatus.demoPaid => 'demo_paid',
    BookingPaymentStatus.demoRefunded => 'demo_refunded',
  };

  String get displayName => switch (this) {
    BookingPaymentStatus.unpaid => 'Unpaid',
    BookingPaymentStatus.demoPaid => 'Demo Paid',
    BookingPaymentStatus.demoRefunded => 'Demo Refunded',
  };

  static BookingPaymentStatus fromDatabaseValue(String value) {
    return switch (value) {
      'unpaid' => BookingPaymentStatus.unpaid,
      'demo_paid' => BookingPaymentStatus.demoPaid,
      'demo_refunded' => BookingPaymentStatus.demoRefunded,
      _ => throw FormatException('Unsupported booking payment status: $value'),
    };
  }
}
