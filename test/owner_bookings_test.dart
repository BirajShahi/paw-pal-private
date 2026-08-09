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

  int cancelCalls = 0;
  Object? throwOnCancel;
  Duration delay = Duration.zero;
  final List<String> cancelIds = [];

  @override
  Future<BookingModel> cancelBooking(String bookingId) async {
    cancelCalls++;
    cancelIds.add(bookingId);

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (throwOnCancel != null) {
      throw throwOnCancel!;
    }

    return BookingModel(
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
      requestedStart: DateTime.now().add(const Duration(days: 2)),
      ownerNotes: 'Please keep him on the leash.',
      status: BookingStatus.cancelled,
      paymentStatus: BookingPaymentStatus.unpaid,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 9),
    );
  }
}

BookingModel _booking({
  String id = 'booking-1',
  BookingStatus status = BookingStatus.pending,
  DateTime? requestedStart,
  String serviceName = 'Dog Walking',
  String petName = 'Milo',
  double price = 30,
  int? duration = 45,
  String? notes = 'Please keep him on the leash.',
}) {
  return BookingModel(
    id: id,
    ownerId: 'owner-1',
    petId: 'pet-1',
    sitterId: 'sitter-1',
    sitterServiceId: 'offer-1',
    petNameSnapshot: petName,
    serviceCodeSnapshot: 'dog_walk',
    serviceNameSnapshot: serviceName,
    priceSnapshot: price,
    estimatedDurationMinutes: duration,
    requestedStart:
        requestedStart ?? DateTime.now().add(const Duration(days: 3)),
    ownerNotes: notes,
    status: status,
    paymentStatus: BookingPaymentStatus.unpaid,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
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
      // Already initialised by another test file in this process.
    }
  });

  group('owner bookings grouping', () {
    final now = DateTime(2026, 8, 9, 12);

    test('future pending/accepted go to Upcoming; others to History', () {
      final pendingFuture = _booking(
        id: 'u1',
        status: BookingStatus.pending,
        requestedStart: now.add(const Duration(days: 1)),
      );
      final acceptedFuture = _booking(
        id: 'u2',
        status: BookingStatus.accepted,
        requestedStart: now.add(const Duration(days: 2)),
      );
      final pendingPast = _booking(
        id: 'h1',
        status: BookingStatus.pending,
        requestedStart: now.subtract(const Duration(days: 1)),
      );
      final completed = _booking(
        id: 'h2',
        status: BookingStatus.completed,
        requestedStart: now.add(const Duration(days: 1)),
      );
      final cancelled = _booking(
        id: 'h3',
        status: BookingStatus.cancelled,
        requestedStart: now.add(const Duration(days: 5)),
      );
      final declined = _booking(
        id: 'h4',
        status: BookingStatus.declined,
        requestedStart: now.add(const Duration(days: 4)),
      );

      final sections = partitionOwnerBookings([
        acceptedFuture,
        cancelled,
        pendingPast,
        pendingFuture,
        declined,
        completed,
      ], now: now);

      expect(sections.upcoming.map((b) => b.id), ['u1', 'u2']);
      expect(sections.history.map((b) => b.id), ['h3', 'h4', 'h2', 'h1']);
    });

    test('cancel eligibility is only pending or accepted', () {
      expect(
        canOwnerCancelBooking(_booking(status: BookingStatus.pending)),
        isTrue,
      );
      expect(
        canOwnerCancelBooking(_booking(status: BookingStatus.accepted)),
        isTrue,
      );
      expect(
        canOwnerCancelBooking(_booking(status: BookingStatus.declined)),
        isFalse,
      );
      expect(
        canOwnerCancelBooking(_booking(status: BookingStatus.cancelled)),
        isFalse,
      );
      expect(
        canOwnerCancelBooking(_booking(status: BookingStatus.completed)),
        isFalse,
      );
    });
  });

  group('owner route protection', () {
    test('bookings route is an owner route', () {
      expect(isOwnerRouteLocation(AppRoutes.bookings), isTrue);
      expect(isOwnerRouteLocation(AppRoutes.sitterDashboard), isFalse);
    });
  });

  group('OwnerBookingsScreen', () {
    late _RecordingBookingRepository repository;
    late List<BookingModel> bookings;
    late int bookingsLoads;

    Future<void> pumpScreen(WidgetTester tester) async {
      repository = _RecordingBookingRepository(Supabase.instance.client);
      bookingsLoads = 0;

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: AppRoutes.bookings,
        routes: [
          GoRoute(
            path: AppRoutes.bookings,
            builder: (context, state) =>
                const Scaffold(body: OwnerBookingsScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiRecommendation,
            builder: (context, state) =>
                const Scaffold(body: Text('AI recommendation screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repository),
            currentOwnerBookingsProvider.overrideWith((ref) async {
              bookingsLoads++;
              return List<BookingModel>.from(bookings);
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows empty state', (tester) async {
      bookings = [];
      await pumpScreen(tester);

      expect(find.text('You have no bookings yet.'), findsOneWidget);
      expect(find.text('Find a Service'), findsOneWidget);

      await tester.tap(find.text('Find a Service'));
      await tester.pumpAndSettle();
      expect(find.text('AI recommendation screen'), findsOneWidget);
    });

    testWidgets('shows pending and accepted cards with snapshots', (
      tester,
    ) async {
      bookings = [
        _booking(
          id: 'pending-1',
          status: BookingStatus.pending,
          serviceName: 'Dog Walking',
          petName: 'Milo',
          price: 30,
          duration: 45,
        ),
        _booking(
          id: 'accepted-1',
          status: BookingStatus.accepted,
          serviceName: 'Full Grooming',
          petName: 'Buddy',
          price: 55.5,
          duration: 60,
          notes: null,
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Dog Walking'), findsOneWidget);
      expect(find.text('Milo'), findsOneWidget);
      expect(find.text(r'$30.00'), findsOneWidget);
      expect(find.text('45 minutes'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Waiting for sitter response'), findsOneWidget);
      expect(find.text('“Please keep him on the leash.”'), findsOneWidget);

      expect(find.text('Full Grooming'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text(r'$55.50'), findsOneWidget);
      expect(find.text('1 hour'), findsOneWidget);
      expect(find.text('Accepted'), findsWidgets);
      expect(find.text('Booking accepted'), findsOneWidget);

      expect(find.byKey(const Key('cancel_booking_pending-1')), findsOneWidget);
      expect(
        find.byKey(const Key('cancel_booking_accepted-1')),
        findsOneWidget,
      );
    });

    testWidgets('history bookings hide cancel and use History section', (
      tester,
    ) async {
      final past = DateTime.now().subtract(const Duration(days: 2));
      bookings = [
        _booking(
          id: 'completed-1',
          status: BookingStatus.completed,
          requestedStart: past,
          serviceName: 'Home Visit',
        ),
        _booking(
          id: 'past-pending',
          status: BookingStatus.pending,
          requestedStart: past,
          serviceName: 'Past Walk',
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('History'), findsOneWidget);
      expect(find.text('Upcoming'), findsNothing);
      expect(find.text('Home Visit'), findsOneWidget);
      expect(find.text('Past Walk'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(find.byKey(const Key('cancel_booking_completed-1')), findsNothing);
      expect(
        find.byKey(const Key('cancel_booking_past-pending')),
        findsOneWidget,
      );
    });

    testWidgets('Keep Booking does not call repository', (tester) async {
      bookings = [_booking(id: 'pending-1')];
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('cancel_booking_pending-1')));
      await tester.pumpAndSettle();
      expect(find.text('Cancel booking?'), findsOneWidget);

      await tester.tap(find.text('Keep Booking'));
      await tester.pumpAndSettle();

      expect(repository.cancelCalls, 0);
      expect(find.text('Cancel booking?'), findsNothing);
      expect(find.text('Dog Walking'), findsOneWidget);
    });

    testWidgets('confirm cancel calls repository once and refreshes', (
      tester,
    ) async {
      bookings = [_booking(id: 'pending-1')];
      await pumpScreen(tester);
      repository.delay = const Duration(milliseconds: 250);
      final loadsBefore = bookingsLoads;

      await tester.tap(find.byKey(const Key('cancel_booking_pending-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_cancel_booking')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_cancel_booking')));
      await tester.pump();

      expect(repository.cancelCalls, 1);

      await tester.pumpAndSettle();

      expect(repository.cancelCalls, 1);
      expect(repository.cancelIds, ['pending-1']);
      expect(bookingsLoads, greaterThan(loadsBefore));
      expect(find.text('Dog Walking booking was cancelled.'), findsOneWidget);
    });

    testWidgets('cancellation failure shows error and keeps list', (
      tester,
    ) async {
      bookings = [_booking(id: 'pending-1')];
      await pumpScreen(tester);
      repository.throwOnCancel = const BookingException(
        'This booking status change is not allowed.',
      );

      await tester.tap(find.byKey(const Key('cancel_booking_pending-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_cancel_booking')));
      await tester.pumpAndSettle();

      expect(
        find.text('This booking status change is not allowed.'),
        findsOneWidget,
      );
      expect(find.text('Cancel booking?'), findsOneWidget);
      expect(find.text('Dog Walking'), findsOneWidget);
      expect(repository.cancelCalls, 1);
    });
  });
}
