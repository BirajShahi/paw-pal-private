import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/features/bookings/booking_model.dart';
import 'package:paw_pal/features/bookings/booking_payment_status.dart';
import 'package:paw_pal/features/bookings/booking_providers.dart';
import 'package:paw_pal/features/bookings/booking_repository.dart';
import 'package:paw_pal/features/bookings/booking_status.dart';
import 'package:paw_pal/features/bookings/card_payment_screen.dart';
import 'package:paw_pal/features/bookings/card_payment_validators.dart';
import 'package:paw_pal/features/bookings/owner_bookings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryLocalStorage extends LocalStorage {
  const _MemoryLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<void> persistSession(String persistSessionString) async {}

  @override
  Future<void> removePersistedSession() async {}
}

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async => _map[key];

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}

class _RecordingBookingRepository extends BookingRepository {
  _RecordingBookingRepository(super.client);

  int demoPayCalls = 0;
  final List<String> demoPayIds = [];
  final List<Object?> demoPayExtraArgs = [];
  Object? throwOnDemoPay;
  Duration delay = Duration.zero;
  BookingModel? booking;

  @override
  Future<BookingModel> getBookingById(String bookingId) async {
    final current = booking;
    if (current == null || current.id != bookingId) {
      throw const BookingException('This booking is unavailable.');
    }
    return current;
  }

  @override
  Future<BookingModel> demoPayBooking(String bookingId) async {
    demoPayCalls++;
    demoPayIds.add(bookingId);
    // Prove no card payload is attached to this call site.
    demoPayExtraArgs.add(null);

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (throwOnDemoPay != null) {
      throw throwOnDemoPay!;
    }

    final paid = BookingModel(
      id: bookingId,
      ownerId: 'owner-1',
      petId: 'pet-1',
      sitterId: 'sitter-1',
      sitterServiceId: 'offer-1',
      petNameSnapshot: 'Milo',
      serviceCodeSnapshot: 'dog_walk',
      serviceNameSnapshot: 'Dog Walking',
      priceSnapshot: 30,
      estimatedDurationMinutes: 45,
      requestedStart: DateTime.utc(2026, 8, 12, 0, 30),
      status: BookingStatus.accepted,
      paymentStatus: BookingPaymentStatus.demoPaid,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 9),
    );
    booking = paid;
    return paid;
  }
}

BookingModel _payableBooking({
  String id = 'accepted-1',
  BookingStatus status = BookingStatus.accepted,
  BookingPaymentStatus paymentStatus = BookingPaymentStatus.unpaid,
}) {
  return BookingModel(
    id: id,
    ownerId: 'owner-1',
    petId: 'pet-1',
    sitterId: 'sitter-1',
    sitterServiceId: 'offer-1',
    petNameSnapshot: 'Milo',
    serviceCodeSnapshot: 'dog_walk',
    serviceNameSnapshot: 'Dog Walking',
    priceSnapshot: 30,
    estimatedDurationMinutes: 45,
    requestedStart: DateTime.utc(2026, 8, 12, 0, 30),
    status: status,
    paymentStatus: paymentStatus,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 9),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        publishableKey: 'test-publishable-key',
        authOptions: FlutterAuthClientOptions(
          localStorage: const _MemoryLocalStorage(),
          pkceAsyncStorage: _MemoryAsyncStorage(),
        ),
      );
    } catch (_) {
      // Already initialized by another test file.
    }
  });

  group('card validators', () {
    test('rejects empty cardholder and invalid lengths', () {
      expect(validateCardholderName(''), isNotNull);
      expect(validateCardholderName('A'), isNotNull);
      expect(validateCardholderName('Alex Smith'), isNull);
    });

    test('rejects invalid card numbers', () {
      expect(validateCardNumber('4242'), isNotNull);
      expect(validateCardNumber('4242 4242 4242 4242'), isNull);
      expect(digitsOnly('4242 4242 4242 4242'), '4242424242424242');
      expect(formatCardNumberGroups('4242424242424242'), '4242 4242 4242 4242');
    });

    test('rejects invalid and expired expiry dates', () {
      expect(validateExpiryDate('13/28'), isNotNull);
      expect(validateExpiryDate('1/28'), isNotNull);
      expect(validateExpiryDate('01/20', now: DateTime(2026, 8, 1)), isNotNull);
      expect(validateExpiryDate('12/28', now: DateTime(2026, 8, 1)), isNull);
    });

    test('rejects invalid CVV', () {
      expect(validateCvv('12'), isNotNull);
      expect(validateCvv('12a'), isNotNull);
      expect(validateCvv('123'), isNull);
    });
  });

  group('payment route protection', () {
    test('payment path is an owner route', () {
      expect(
        isOwnerRouteLocation(AppRoutes.bookingPayment('booking-1')),
        isTrue,
      );
      expect(
        isSitterRouteLocation(AppRoutes.bookingPayment('booking-1')),
        isFalse,
      );
    });

    test('Pay by Card eligibility stays accepted + unpaid', () {
      expect(canOwnerDemoPayBooking(_payableBooking()), isTrue);
      expect(
        canOwnerDemoPayBooking(_payableBooking(status: BookingStatus.pending)),
        isFalse,
      );
      expect(
        canOwnerDemoPayBooking(
          _payableBooking(paymentStatus: BookingPaymentStatus.demoPaid),
        ),
        isFalse,
      );
    });
  });

  group('CardPaymentScreen', () {
    late _RecordingBookingRepository repository;
    late int ownerBookingsLoads;
    late int bookingByIdLoads;

    Future<void> pumpScreen(
      WidgetTester tester, {
      required BookingModel booking,
    }) async {
      repository = _RecordingBookingRepository(Supabase.instance.client)
        ..booking = booking;
      ownerBookingsLoads = 0;
      bookingByIdLoads = 0;

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: AppRoutes.bookingPayment(booking.id),
        routes: [
          GoRoute(
            path: '/bookings/:bookingId/payment',
            builder: (context, state) {
              final bookingId = state.pathParameters['bookingId']!;
              return CardPaymentScreen(bookingId: bookingId);
            },
          ),
          GoRoute(
            path: AppRoutes.bookings,
            builder: (context, state) =>
                const Scaffold(body: Text('Owner bookings')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repository),
            currentOwnerBookingsProvider.overrideWith((ref) async {
              ownerBookingsLoads++;
              return const <BookingModel>[];
            }),
            bookingByIdProvider(booking.id).overrideWith((ref) async {
              bookingByIdLoads++;
              return repository.getBookingById(booking.id);
            }),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              // Keep list/provider watched so payment invalidation refreshes.
              ref.watch(currentOwnerBookingsProvider);
              ref.watch(bookingByIdProvider(booking.id));
              return child!;
            },
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillValidCard(WidgetTester tester) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Alex Smith');
      await tester.enterText(fields.at(1), '4242424242424242');
      await tester.enterText(fields.at(2), '1228');
      await tester.enterText(fields.at(3), '123');
      await tester.pump();
    }

    testWidgets('shows summary amount and simulation notice', (tester) async {
      await pumpScreen(tester, booking: _payableBooking());

      expect(find.text('Payment'), findsWidgets);
      expect(find.text('Dog Walking'), findsOneWidget);
      expect(find.text('Milo'), findsOneWidget);
      expect(find.textContaining(r'$30.00 AUD'), findsOneWidget);
      expect(find.text('Pay \$30.00'), findsOneWidget);
      expect(
        find.textContaining('Payment simulation for the PawPal university'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No real card will be charged.'),
        findsOneWidget,
      );
      expect(find.textContaining('stripe'), findsNothing);
      expect(find.textContaining('Stripe'), findsNothing);
    });

    testWidgets('rejects empty and invalid card fields', (tester) async {
      await pumpScreen(tester, booking: _payableBooking());

      await tester.tap(find.byKey(const Key('confirm_card_payment')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the cardholder name.'), findsOneWidget);
      expect(repository.demoPayCalls, 0);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Alex Smith');
      await tester.enterText(fields.at(1), '4242');
      await tester.enterText(fields.at(2), '13/28');
      await tester.enterText(fields.at(3), '12');
      await tester.tap(find.byKey(const Key('confirm_card_payment')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a 16-digit card number.'), findsOneWidget);
      expect(
        find.text('Enter a valid expiry month between 01 and 12.'),
        findsOneWidget,
      );
      expect(find.text('Enter a 3-digit CVV.'), findsOneWidget);
      expect(repository.demoPayCalls, 0);
    });

    testWidgets(
      'valid form submits only booking id and shows Demo Paid success',
      (tester) async {
        await pumpScreen(tester, booking: _payableBooking());
        repository.delay = const Duration(milliseconds: 250);
        final ownerLoadsBefore = ownerBookingsLoads;
        final byIdLoadsBefore = bookingByIdLoads;

        await fillValidCard(tester);

        final pay = find.byKey(const Key('confirm_card_payment'));
        await tester.tap(pay);
        await tester.pump();
        await tester.tap(pay);
        await tester.pump();

        expect(repository.demoPayCalls, 1);
        await tester.pumpAndSettle();

        expect(repository.demoPayCalls, 1);
        expect(repository.demoPayIds, ['accepted-1']);
        expect(repository.demoPayExtraArgs, [null]);
        expect(ownerBookingsLoads, greaterThan(ownerLoadsBefore));
        expect(bookingByIdLoads, greaterThan(byIdLoadsBefore));
        expect(find.text('Payment successful'), findsOneWidget);
        expect(find.text('Demo Paid'), findsOneWidget);
        expect(
          find.textContaining('No real money was charged.'),
          findsOneWidget,
        );
        expect(find.text('Back to Bookings'), findsOneWidget);

        await tester.tap(find.text('Back to Bookings'));
        await tester.pumpAndSettle();
        expect(find.text('Owner bookings'), findsOneWidget);
      },
    );

    testWidgets('unavailable booking shows friendly state', (tester) async {
      await pumpScreen(
        tester,
        booking: _payableBooking(paymentStatus: BookingPaymentStatus.demoPaid),
      );

      expect(
        find.text('This booking is no longer available for payment.'),
        findsOneWidget,
      );
      expect(find.text('Back to Bookings'), findsOneWidget);
      expect(find.text('Pay \$30.00'), findsNothing);
    });

    testWidgets('RPC failure keeps form and shows friendly error', (
      tester,
    ) async {
      await pumpScreen(tester, booking: _payableBooking());
      repository.throwOnDemoPay = const BookingException(
        'This booking is no longer available for payment.',
      );

      await fillValidCard(tester);
      await tester.tap(find.byKey(const Key('confirm_card_payment')));
      await tester.pumpAndSettle();

      expect(
        find.text('This booking is no longer available for payment.'),
        findsOneWidget,
      );
      expect(find.text('Pay \$30.00'), findsOneWidget);
      expect(find.text('Alex Smith'), findsWidgets);
      expect(repository.demoPayCalls, 1);
    });
  });
}
