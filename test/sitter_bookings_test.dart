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
import 'package:paw_pal/features/bookings/sitter_bookings_screen.dart';
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

  int acceptCalls = 0;
  int declineCalls = 0;
  int completeCalls = 0;
  Object? throwOnAction;
  Duration delay = Duration.zero;

  BookingModel _result(String bookingId, BookingStatus status) {
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
      status: status,
      paymentStatus: BookingPaymentStatus.unpaid,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 9),
    );
  }

  Future<BookingModel> _run(
    String bookingId,
    BookingStatus status,
    void Function() count,
  ) async {
    count();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (throwOnAction != null) {
      throw throwOnAction!;
    }
    return _result(bookingId, status);
  }

  @override
  Future<BookingModel> acceptBooking(String bookingId) {
    return _run(bookingId, BookingStatus.accepted, () => acceptCalls++);
  }

  @override
  Future<BookingModel> declineBooking(String bookingId) {
    return _run(bookingId, BookingStatus.declined, () => declineCalls++);
  }

  @override
  Future<BookingModel> completeBooking(String bookingId) {
    return _run(bookingId, BookingStatus.completed, () => completeCalls++);
  }
}

BookingModel _booking({
  String id = 'booking-1',
  BookingStatus status = BookingStatus.pending,
  BookingPaymentStatus paymentStatus = BookingPaymentStatus.unpaid,
  DateTime? requestedStart,
  String serviceName = 'Dog Walking',
  String petName = 'Milo',
  double price = 30,
  int? duration = 45,
  String? notes = 'Please keep him on the leash.',
  String? medicalNotes,
  String? behaviourNotes,
  String? careNotes,
}) {
  return BookingModel(
    id: id,
    ownerId: 'owner-1',
    petId: 'pet-1',
    sitterId: 'sitter-1',
    sitterServiceId: 'offer-1',
    petNameSnapshot: petName,
    petMedicalNotesSnapshot: medicalNotes,
    petBehaviourNotesSnapshot: behaviourNotes,
    petCareNotesSnapshot: careNotes,
    serviceCodeSnapshot: 'dog_walk',
    serviceNameSnapshot: serviceName,
    priceSnapshot: price,
    estimatedDurationMinutes: duration,
    requestedStart:
        requestedStart ?? DateTime.now().add(const Duration(days: 3)),
    ownerNotes: notes,
    status: status,
    paymentStatus: paymentStatus,
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

  group('sitter bookings grouping', () {
    final now = DateTime(2026, 8, 9, 12);

    test('partitions requests, upcoming and history correctly', () {
      final pending = _booking(
        id: 'r1',
        status: BookingStatus.pending,
        requestedStart: now.add(const Duration(days: 1)),
      );
      final acceptedFuture = _booking(
        id: 'u1',
        status: BookingStatus.accepted,
        requestedStart: now.add(const Duration(days: 2)),
      );
      final acceptedPast = _booking(
        id: 'h1',
        status: BookingStatus.accepted,
        requestedStart: now.subtract(const Duration(hours: 1)),
      );
      final declined = _booking(
        id: 'h2',
        status: BookingStatus.declined,
        requestedStart: now.add(const Duration(days: 3)),
      );
      final cancelled = _booking(
        id: 'h3',
        status: BookingStatus.cancelled,
        requestedStart: now.add(const Duration(days: 4)),
      );
      final completed = _booking(
        id: 'h4',
        status: BookingStatus.completed,
        requestedStart: now.subtract(const Duration(days: 1)),
      );

      final sections = partitionSitterBookings([
        acceptedFuture,
        cancelled,
        pending,
        declined,
        acceptedPast,
        completed,
      ], now: now);

      expect(sections.requests.map((b) => b.id), ['r1']);
      expect(sections.upcoming.map((b) => b.id), ['u1']);
      expect(sections.history.map((b) => b.id), ['h3', 'h2', 'h1', 'h4']);
    });

    test('action eligibility helpers', () {
      final now = DateTime(2026, 8, 9, 12);
      expect(
        canSitterRespondToBooking(_booking(status: BookingStatus.pending)),
        isTrue,
      );
      expect(
        canSitterRespondToBooking(_booking(status: BookingStatus.accepted)),
        isFalse,
      );

      expect(
        canSitterCompleteBooking(
          _booking(
            status: BookingStatus.accepted,
            requestedStart: now.add(const Duration(days: 1)),
          ),
          now: now,
        ),
        isFalse,
      );
      expect(
        canSitterCompleteBooking(
          _booking(
            status: BookingStatus.accepted,
            requestedStart: now.subtract(const Duration(hours: 1)),
          ),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('sitter route protection', () {
    test('sitter bookings is a sitter route and not an owner route', () {
      expect(isSitterRouteLocation(AppRoutes.sitterBookings), isTrue);
      expect(isOwnerRouteLocation(AppRoutes.sitterBookings), isFalse);
      expect(isSitterRouteLocation(AppRoutes.bookings), isFalse);
    });
  });

  group('SitterBookingsScreen', () {
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
        initialLocation: AppRoutes.sitterBookings,
        routes: [
          GoRoute(
            path: AppRoutes.sitterBookings,
            builder: (context, state) => const SitterBookingsScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repository),
            currentSitterBookingsProvider.overrideWith((ref) async {
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

      expect(find.text('No booking requests yet.'), findsOneWidget);
      expect(
        find.textContaining('When pet owners request one of your services'),
        findsOneWidget,
      );
    });

    testWidgets('shows pending under Requests with actions', (tester) async {
      bookings = [
        _booking(id: 'pending-1', status: BookingStatus.pending),
        _booking(
          id: 'accepted-future',
          status: BookingStatus.accepted,
          requestedStart: DateTime.now().add(const Duration(days: 2)),
        ),
        _booking(
          id: 'completed-1',
          status: BookingStatus.completed,
          requestedStart: DateTime.now().subtract(const Duration(days: 1)),
          serviceName: 'Home Visit',
          duration: 60,
          notes: null,
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Dog Walking'), findsWidgets);
      expect(find.text('Pet: Milo'), findsWidgets);
      expect(find.text(r'$30.00'), findsWidgets);
      expect(find.text('45 minutes'), findsWidgets);
      expect(find.text('Owner notes'), findsWidgets);
      expect(find.text('“Please keep him on the leash.”'), findsWidgets);
      expect(find.text('Waiting for your response'), findsOneWidget);

      expect(find.byKey(const Key('accept_booking_pending-1')), findsOneWidget);
      expect(
        find.byKey(const Key('decline_booking_pending-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('complete_booking_accepted-future')),
        findsNothing,
      );
      expect(find.byKey(const Key('accept_booking_completed-1')), findsNothing);
      expect(find.text('Home Visit'), findsOneWidget);
      expect(find.text('1 hour'), findsOneWidget);
    });

    testWidgets('past accepted shows complete and hides pending actions', (
      tester,
    ) async {
      bookings = [
        _booking(
          id: 'accepted-past',
          status: BookingStatus.accepted,
          requestedStart: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('History'), findsOneWidget);
      expect(find.text('Upcoming'), findsNothing);
      expect(
        find.byKey(const Key('complete_booking_accepted-past')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('accept_booking_accepted-past')),
        findsNothing,
      );
    });

    testWidgets('declined and completed bookings show no sitter actions', (
      tester,
    ) async {
      final past = DateTime.now().subtract(const Duration(days: 1));
      bookings = [
        _booking(
          id: 'declined-1',
          status: BookingStatus.declined,
          requestedStart: past,
        ),
        _booking(
          id: 'completed-1',
          status: BookingStatus.completed,
          requestedStart: past,
          serviceName: 'Home Visit',
        ),
        _booking(
          id: 'cancelled-1',
          status: BookingStatus.cancelled,
          paymentStatus: BookingPaymentStatus.demoRefunded,
          requestedStart: past,
          serviceName: 'Cancelled Walk',
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('History'), findsOneWidget);
      expect(find.text('Declined'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Demo Refunded'), findsOneWidget);
      expect(find.byKey(const Key('accept_booking_declined-1')), findsNothing);
      expect(find.byKey(const Key('decline_booking_declined-1')), findsNothing);
      expect(
        find.byKey(const Key('complete_booking_declined-1')),
        findsNothing,
      );
      expect(find.byKey(const Key('accept_booking_completed-1')), findsNothing);
      expect(
        find.byKey(const Key('decline_booking_completed-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('complete_booking_completed-1')),
        findsNothing,
      );
      expect(find.byKey(const Key('accept_booking_cancelled-1')), findsNothing);
      expect(
        find.byKey(const Key('complete_booking_cancelled-1')),
        findsNothing,
      );
    });

    testWidgets('future accepted booking cannot be completed', (tester) async {
      bookings = [
        _booking(
          id: 'accepted-future',
          status: BookingStatus.accepted,
          requestedStart: DateTime.now().add(const Duration(days: 2)),
          paymentStatus: BookingPaymentStatus.demoPaid,
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Demo Paid'), findsOneWidget);
      expect(
        find.byKey(const Key('complete_booking_accepted-future')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('accept_booking_accepted-future')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('decline_booking_accepted-future')),
        findsNothing,
      );
    });

    testWidgets('dismissing accept dialog does not call repository', (
      tester,
    ) async {
      bookings = [_booking(id: 'pending-1')];
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('accept_booking_pending-1')));
      await tester.pumpAndSettle();
      expect(find.text('Accept booking?'), findsOneWidget);

      await tester.tap(find.text('Not Yet'));
      await tester.pumpAndSettle();

      expect(repository.acceptCalls, 0);
      expect(find.text('Accept booking?'), findsNothing);
    });

    testWidgets('accept calls repository once and refreshes', (tester) async {
      bookings = [_booking(id: 'pending-1')];
      await pumpScreen(tester);
      repository.delay = const Duration(milliseconds: 250);
      final loadsBefore = bookingsLoads;

      await tester.tap(find.byKey(const Key('accept_booking_pending-1')));
      await tester.pumpAndSettle();

      final confirm = find.byKey(const Key('confirm_accept_booking'));
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(confirm);
      await tester.pump();

      expect(repository.acceptCalls, 1);
      await tester.pumpAndSettle();

      expect(repository.acceptCalls, 1);
      expect(bookingsLoads, greaterThan(loadsBefore));
      expect(find.text('Dog Walking booking was accepted.'), findsOneWidget);
    });

    testWidgets('decline calls repository once', (tester) async {
      bookings = [_booking(id: 'pending-1')];
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('decline_booking_pending-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_decline_booking')));
      await tester.pumpAndSettle();

      expect(repository.declineCalls, 1);
      expect(find.text('Dog Walking booking was declined.'), findsOneWidget);
    });

    testWidgets('complete calls repository once', (tester) async {
      bookings = [
        _booking(
          id: 'accepted-past',
          status: BookingStatus.accepted,
          requestedStart: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('complete_booking_accepted-past')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_complete_booking')));
      await tester.pumpAndSettle();

      expect(repository.completeCalls, 1);
      expect(find.text('Dog Walking booking was completed.'), findsOneWidget);
    });

    testWidgets('failed action shows error and refreshes', (tester) async {
      bookings = [_booking(id: 'pending-1')];
      await pumpScreen(tester);
      repository.throwOnAction = const BookingException(
        'This booking status change is not allowed.',
      );
      final loadsBefore = bookingsLoads;

      await tester.tap(find.byKey(const Key('accept_booking_pending-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_accept_booking')));
      await tester.pumpAndSettle();

      expect(
        find.text('This booking status change is not allowed.'),
        findsOneWidget,
      );
      expect(find.text('Accept booking?'), findsOneWidget);
      expect(bookingsLoads, greaterThan(loadsBefore));
    });

    testWidgets('shows populated pet care notes separately from owner notes', (
      tester,
    ) async {
      bookings = [
        _booking(
          id: 'care-1',
          medicalNotes: 'Allergic to chicken.',
          behaviourNotes: 'Nervous around large dogs.',
          careNotes: 'Needs fresh water available at all times.',
          notes: 'Please use the side gate when arriving.',
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('Pet care information'), findsOneWidget);
      expect(find.text('Medical'), findsOneWidget);
      expect(find.text('“Allergic to chicken.”'), findsOneWidget);
      expect(find.text('Behaviour'), findsOneWidget);
      expect(find.text('“Nervous around large dogs.”'), findsOneWidget);
      expect(find.text('Care instructions'), findsOneWidget);
      expect(
        find.text('“Needs fresh water available at all times.”'),
        findsOneWidget,
      );
      expect(find.text('Owner notes'), findsOneWidget);
      expect(
        find.text('“Please use the side gate when arriving.”'),
        findsOneWidget,
      );
    });

    testWidgets('omits blank pet care note fields and empty section', (
      tester,
    ) async {
      bookings = [
        _booking(
          id: 'care-blank',
          medicalNotes: '   ',
          behaviourNotes: null,
          careNotes: 'Needs access to water.',
          notes: null,
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('Pet care information'), findsOneWidget);
      expect(find.text('Care instructions'), findsOneWidget);
      expect(find.text('“Needs access to water.”'), findsOneWidget);
      expect(find.text('Medical'), findsNothing);
      expect(find.text('Behaviour'), findsNothing);
      expect(find.text('Owner notes'), findsNothing);
    });

    testWidgets('hides pet care section when all snapshots are blank', (
      tester,
    ) async {
      bookings = [
        _booking(
          id: 'care-none',
          medicalNotes: null,
          behaviourNotes: '  ',
          careNotes: '',
          notes: 'Please keep him on the leash.',
        ),
      ];
      await pumpScreen(tester);

      expect(find.text('Pet care information'), findsNothing);
      expect(find.text('Medical'), findsNothing);
      expect(find.text('Owner notes'), findsOneWidget);
    });
  });

  group('pet care note helpers', () {
    test('usefulPetCareNote trims and drops blanks', () {
      expect(usefulPetCareNote(null), isNull);
      expect(usefulPetCareNote(''), isNull);
      expect(usefulPetCareNote('   '), isNull);
      expect(usefulPetCareNote('  Hello  '), 'Hello');
    });

    test('bookingHasPetCareInformation requires useful text', () {
      expect(bookingHasPetCareInformation(_booking()), isFalse);
      expect(
        bookingHasPetCareInformation(_booking(careNotes: 'Needs water')),
        isTrue,
      );
      expect(
        bookingHasPetCareInformation(_booking(medicalNotes: '  ')),
        isFalse,
      );
    });
  });
}
