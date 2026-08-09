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
import 'package:paw_pal/features/bookings/create_booking_request.dart';
import 'package:paw_pal/features/bookings/create_booking_screen.dart';
import 'package:paw_pal/features/pets/pet_model.dart';
import 'package:paw_pal/features/pets/pet_providers.dart';
import 'package:paw_pal/features/services/service_category.dart';
import 'package:paw_pal/features/services/service_model.dart';
import 'package:paw_pal/features/services/sitter_profile_summary.dart';
import 'package:paw_pal/features/services/sitter_service_model.dart';
import 'package:paw_pal/features/services/sitter_service_providers.dart';
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

  int createCalls = 0;
  Object? throwOnCreate;
  Duration delay = Duration.zero;
  final List<CreateBookingRequest> createArgs = [];

  @override
  Future<BookingModel> createBooking(CreateBookingRequest request) async {
    createCalls++;
    createArgs.add(request);

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (throwOnCreate != null) {
      throw throwOnCreate!;
    }

    return BookingModel(
      id: 'booking-1',
      ownerId: 'owner-1',
      petId: request.petId,
      sitterId: 'sitter-1',
      sitterServiceId: request.sitterServiceId,
      petNameSnapshot: 'Buddy',
      serviceCodeSnapshot: 'dog_walk',
      serviceNameSnapshot: 'Dog Walking',
      priceSnapshot: 30,
      estimatedDurationMinutes: 45,
      requestedStart: request.requestedStart,
      ownerNotes: request.ownerNotes,
      status: BookingStatus.pending,
      paymentStatus: BookingPaymentStatus.unpaid,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );
  }
}

ServiceModel _service({String name = 'Dog Walking'}) {
  return ServiceModel(
    id: 'svc-1',
    code: 'dog_walk',
    name: name,
    category: ServiceCategory.walking,
    description: 'A neighbourhood walk with water breaks.',
    includedItems: const ['Water breaks'],
    recommendationTags: const ['exercise'],
    canBeAddOn: false,
    isActive: true,
    displayOrder: 10,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

SitterServiceModel _offering({String id = 'offer-1'}) {
  return SitterServiceModel(
    id: id,
    sitterId: 'sitter-1',
    serviceId: 'svc-1',
    price: 30,
    estimatedDurationMinutes: 45,
    serviceNotes: 'One-on-one walks with water breaks.',
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 2),
    updatedAt: DateTime.utc(2026, 1, 2),
    service: _service(),
    sitter: SitterProfileSummary(
      id: 'sitter-1',
      fullName: "Sarah's Pet Care",
      suburb: 'Mickleham',
      postcode: '3064',
      serviceDescription: 'Experienced walker',
    ),
  );
}

PetModel _pet({
  String id = 'pet-1',
  String name = 'Buddy',
  String species = 'Dog',
  String? breed = 'Labrador',
}) {
  return PetModel(
    id: id,
    ownerId: 'owner-1',
    name: name,
    species: species,
    breed: breed,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
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

  group('owner booking route protection', () {
    test('treats create-booking path as an owner route', () {
      expect(isOwnerRouteLocation('/bookings/new/offer-1'), isTrue);
      expect(isOwnerRouteLocation(AppRoutes.bookings), isTrue);
      expect(isOwnerRouteLocation(AppRoutes.sitterDashboard), isFalse);
    });
  });

  group('create booking helpers', () {
    test('combines date and time and rejects past DateTime via request', () {
      final past = combineBookingDateTime(
        DateTime(2020, 1, 1),
        const TimeOfDay(hour: 9, minute: 0),
      );
      expect(
        () => CreateBookingRequest(
          petId: 'pet-1',
          sitterServiceId: 'offer-1',
          requestedStart: past,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects owner notes over 1000 characters', () {
      final start = DateTime.now().toUtc().add(const Duration(days: 2));
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

  group('CreateBookingScreen', () {
    late _RecordingBookingRepository repository;
    late int ownerBookingsLoads;
    late String capturedOfferingId;

    Future<void> pumpScreen(
      WidgetTester tester, {
      required String offeringId,
      required SitterServiceModel offering,
      required List<PetModel> pets,
      DateTime? initialDate,
      TimeOfDay? initialTime,
      String? initialPetId,
    }) async {
      repository = _RecordingBookingRepository(Supabase.instance.client);
      ownerBookingsLoads = 0;
      capturedOfferingId = '';

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: AppRoutes.bookingNew(offeringId),
        routes: [
          GoRoute(
            path: '/bookings/new/:offeringId',
            builder: (context, state) {
              final id = state.pathParameters['offeringId']!;
              capturedOfferingId = id;
              return CreateBookingScreen(
                offeringId: id,
                debugInitialDate: initialDate,
                debugInitialTime: initialTime,
                debugInitialPetId: initialPetId,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.bookings,
            builder: (context, state) =>
                const Scaffold(body: Text('Owner bookings list')),
          ),
          GoRoute(
            path: AppRoutes.petNew,
            builder: (context, state) =>
                const Scaffold(body: Text('Add pet screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSitterOfferingByIdProvider(
              offeringId,
            ).overrideWith((ref) async => offering),
            currentOwnerPetsProvider.overrideWith((ref) async => pets),
            bookingRepositoryProvider.overrideWithValue(repository),
            currentOwnerBookingsProvider.overrideWith((ref) async {
              ownerBookingsLoads++;
              return const <BookingModel>[];
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('uses offering id route parameter and shows offering', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        offeringId: 'offer-99',
        offering: _offering(id: 'offer-99'),
        pets: [_pet()],
      );

      expect(capturedOfferingId, 'offer-99');
      expect(find.text('Dog Walking'), findsWidgets);
      expect(find.text("Sarah's Pet Care"), findsWidgets);
      expect(find.text('Mickleham 3064'), findsOneWidget);
      expect(find.text(r'$30.00'), findsWidgets);
      expect(find.textContaining('45 minutes'), findsOneWidget);
      expect(find.text('One-on-one walks with water breaks.'), findsOneWidget);
    });

    testWidgets('loads owner pets', (tester) async {
      await pumpScreen(
        tester,
        offeringId: 'offer-1',
        offering: _offering(),
        pets: [
          _pet(name: 'Buddy'),
          _pet(id: 'pet-2', name: 'Milo'),
        ],
      );

      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('Milo'), findsOneWidget);
      expect(find.textContaining('Dog · Labrador'), findsWidgets);
    });

    testWidgets('shows empty state without pets', (tester) async {
      await pumpScreen(
        tester,
        offeringId: 'offer-1',
        offering: _offering(),
        pets: const [],
      );

      expect(
        find.text('You need to add a pet before making a booking.'),
        findsOneWidget,
      );
      expect(find.text('Add a Pet'), findsOneWidget);
      expect(find.byKey(const Key('request_booking_button')), findsNothing);

      await tester.tap(find.text('Add a Pet'));
      await tester.pumpAndSettle();
      expect(find.text('Add pet screen'), findsOneWidget);
    });

    testWidgets('requires pet date and time before enabling submit', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        offeringId: 'offer-1',
        offering: _offering(),
        pets: [_pet()],
      );

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('request_booking_button')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);

      await pumpScreen(
        tester,
        offeringId: 'offer-1',
        offering: _offering(),
        pets: [_pet()],
        initialPetId: 'pet-1',
        initialDate: DateTime.now().add(const Duration(days: 2)),
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );

      final enabled = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('request_booking_button')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets(
      'submits permitted fields once, prevents double submit, invalidates',
      (tester) async {
        final startDate = DateTime.now().add(const Duration(days: 3));

        await pumpScreen(
          tester,
          offeringId: 'offer-1',
          offering: _offering(),
          pets: [_pet()],
          initialPetId: 'pet-1',
          initialDate: startDate,
          initialTime: const TimeOfDay(hour: 11, minute: 30),
        );

        repository.delay = const Duration(milliseconds: 300);

        await tester.enterText(
          find.byType(TextFormField),
          '  Please use the side gate  ',
        );
        await tester.pump();

        final submit = find.byKey(const Key('request_booking_button'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        await tester.tap(submit);
        await tester.pump();

        expect(repository.createCalls, 1);

        await tester.pumpAndSettle();

        expect(repository.createCalls, 1);
        final request = repository.createArgs.single;
        expect(request.petId, 'pet-1');
        expect(request.sitterServiceId, 'offer-1');
        expect(request.ownerNotes, 'Please use the side gate');
        expect(request.requestedStart.hour, 11);
        expect(request.requestedStart.minute, 30);

        final insert = request.toInsertMap(ownerId: 'owner-1');
        expect(insert.containsKey('sitter_id'), isFalse);
        expect(insert.containsKey('price_snapshot'), isFalse);
        expect(insert.containsKey('status'), isFalse);
        expect(insert.containsKey('payment_status'), isFalse);
        expect(insert.containsKey('service_name_snapshot'), isFalse);

        expect(find.text('Owner bookings list'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.text('Owner bookings list')),
        );
        await container.read(currentOwnerBookingsProvider.future);
        expect(ownerBookingsLoads, greaterThan(0));
      },
    );

    testWidgets('failed submission preserves form state', (tester) async {
      final startDate = DateTime.now().add(const Duration(days: 4));
      await pumpScreen(
        tester,
        offeringId: 'offer-1',
        offering: _offering(),
        pets: [_pet()],
        initialPetId: 'pet-1',
        initialDate: startDate,
        initialTime: const TimeOfDay(hour: 14, minute: 0),
      );

      repository.throwOnCreate = const BookingException(
        'The selected service is no longer available.',
      );

      await tester.enterText(find.byType(TextFormField), 'Keep these notes');
      await tester.pump();
      final submit = find.byKey(const Key('request_booking_button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        find.text('The selected service is no longer available.'),
        findsOneWidget,
      );
      expect(find.text('Keep these notes'), findsOneWidget);
      expect(find.text('Buddy'), findsWidgets);
      expect(find.byKey(const Key('request_booking_button')), findsOneWidget);
      expect(find.text('Owner bookings list'), findsNothing);
    });
  });
}
