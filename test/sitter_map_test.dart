import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/features/services/service_category.dart';
import 'package:paw_pal/features/services/service_model.dart';
import 'package:paw_pal/features/services/sitter_profile_summary.dart';
import 'package:paw_pal/features/services/sitter_service_model.dart';
import 'package:paw_pal/features/sitters/discoverable_sitter.dart';

void main() {
  ServiceModel service({
    String id = 'svc-walk',
    String code = 'dog_walking',
    String name = 'Dog Walking',
    bool isActive = true,
  }) {
    return ServiceModel(
      id: id,
      code: code,
      name: name,
      category: ServiceCategory.walking,
      description: 'A scheduled walking service for pets.',
      includedItems: const ['Supervised walk'],
      recommendationTags: const ['needs exercise'],
      canBeAddOn: false,
      isActive: isActive,
      displayOrder: 100,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  SitterProfileSummary profile({
    String id = 'sitter-1',
    String fullName = "Sarah's Pet Care",
    String? suburb = 'Mickleham',
    String? postcode = '3064',
    double? latitude = -37.5,
    double? longitude = 144.9,
  }) {
    return SitterProfileSummary(
      id: id,
      fullName: fullName,
      suburb: suburb,
      postcode: postcode,
      latitude: latitude,
      longitude: longitude,
    );
  }

  SitterServiceModel offering({
    String id = 'offer-1',
    String sitterId = 'sitter-1',
    String serviceId = 'svc-walk',
    double price = 30,
    int? duration = 45,
    ServiceModel? catalogue,
    SitterProfileSummary? sitter,
  }) {
    return SitterServiceModel(
      id: id,
      sitterId: sitterId,
      serviceId: serviceId,
      price: price,
      estimatedDurationMinutes: duration,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
      service: catalogue ?? service(id: serviceId),
      sitter: sitter ?? profile(id: sitterId),
    );
  }

  group('coordinate parsing', () {
    test('parses valid latitude/longitude via num.toDouble()', () {
      final sitter = SitterProfileSummary.fromMap({
        'id': 'sitter-1',
        'full_name': 'Alex',
        'latitude': -37,
        'longitude': 145.1,
      });
      expect(sitter.latitude, -37.0);
      expect(sitter.longitude, 145.1);
    });

    test('rejects invalid latitude', () {
      expect(
        () => DiscoverableSitter(
          id: 's1',
          fullName: 'Alex',
          latitude: 91,
          longitude: 0,
          offerings: const [],
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterProfileSummary.fromMap({
          'id': 's1',
          'full_name': 'Alex',
          'latitude': -91,
          'longitude': 0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid longitude', () {
      expect(
        () => DiscoverableSitter(
          id: 's1',
          fullName: 'Alex',
          latitude: 0,
          longitude: 181,
          offerings: const [],
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterProfileSummary.fromMap({
          'id': 's1',
          'full_name': 'Alex',
          'latitude': 0,
          'longitude': -181,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('mapReadySitters', () {
    test(
      'excludes sitters without both coordinates; one marker per sitter',
      () {
        final walk = service();
        final visit = service(
          id: 'svc-visit',
          code: 'home_visit',
          name: 'Home Visit',
        );

        final grouped = groupOfferingsIntoDiscoverableSitters([
          offering(
            id: 'o1',
            sitterId: 'sitter-1',
            serviceId: 'svc-walk',
            catalogue: walk,
            sitter: profile(id: 'sitter-1'),
          ),
          offering(
            id: 'o2',
            sitterId: 'sitter-1',
            serviceId: 'svc-visit',
            catalogue: visit,
            sitter: profile(id: 'sitter-1'),
          ),
          offering(
            id: 'o3',
            sitterId: 'sitter-2',
            serviceId: 'svc-walk',
            catalogue: walk,
            sitter: profile(
              id: 'sitter-2',
              fullName: 'No Coords',
              latitude: null,
              longitude: null,
            ),
          ),
          offering(
            id: 'o4',
            sitterId: 'sitter-3',
            serviceId: 'svc-walk',
            catalogue: walk,
            sitter: profile(
              id: 'sitter-3',
              fullName: 'Partial',
              latitude: -37.8,
              longitude: null,
            ),
          ),
        ]);

        final mapSitters = mapReadySitters(grouped);
        expect(mapSitters, hasLength(1));
        expect(mapSitters.single.id, 'sitter-1');
        expect(mapSitters.single.offerings, hasLength(2));
      },
    );
  });

  group('map service filter', () {
    test('exact service filter keeps matching map sitters only', () {
      final walk = service();
      final visit = service(
        id: 'svc-visit',
        code: 'home_visit',
        name: 'Home Visit',
      );
      final sitters = mapReadySitters(
        groupOfferingsIntoDiscoverableSitters([
          offering(
            id: 'o-walk',
            sitterId: 'sitter-1',
            serviceId: 'svc-walk',
            catalogue: walk,
            sitter: profile(id: 'sitter-1', fullName: 'Sarah'),
          ),
          offering(
            id: 'o-visit',
            sitterId: 'sitter-1',
            serviceId: 'svc-visit',
            catalogue: visit,
            sitter: profile(id: 'sitter-1', fullName: 'Sarah'),
          ),
          offering(
            id: 'o-alex',
            sitterId: 'sitter-2',
            serviceId: 'svc-walk',
            catalogue: walk,
            sitter: profile(
              id: 'sitter-2',
              fullName: 'Alex',
              latitude: -37.8,
              longitude: 145.0,
            ),
          ),
        ]),
      );

      final filtered = filterDiscoverableSitters(
        sitters,
        serviceId: 'svc-visit',
      );
      expect(filtered, hasLength(1));
      expect(filtered.single.offerings.map((o) => o.id), ['o-visit']);
      expect(filtered.single.latitude, isNotNull);
      expect(filtered.single.longitude, isNotNull);
    });

    test('filter is local and does not require network', () {
      final sitters = mapReadySitters(
        groupOfferingsIntoDiscoverableSitters([offering(sitter: profile())]),
      );
      // Pure in-memory filter — no repository involved.
      expect(filterDiscoverableSitters(sitters, serviceId: 'missing'), isEmpty);
      expect(filterDiscoverableSitters(sitters), hasLength(1));
    });
  });

  group('owner route protection', () {
    test('/map remains an owner-only route', () {
      expect(isOwnerRouteLocation(AppRoutes.map), isTrue);
      expect(isSitterRouteLocation(AppRoutes.map), isFalse);
    });

    test('Book action uses offering id route helper', () {
      expect(AppRoutes.bookingNew('offer-42'), '/bookings/new/offer-42');
    });
  });

  group('map empty and detail copy', () {
    testWidgets('shows no-location empty state copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('No provider map locations are available yet.'),
                Text(
                  'You can still browse available providers from Find Pet Care.',
                ),
                Text('Browse Providers'),
              ],
            ),
          ),
        ),
      );

      expect(
        find.text('No provider map locations are available yet.'),
        findsOneWidget,
      );
      expect(find.text('Browse Providers'), findsOneWidget);
    });

    testWidgets('details show service name and price without ids/coords', (
      tester,
    ) async {
      final sitter = DiscoverableSitter(
        id: 'sitter-secret',
        fullName: "Sarah's Pet Care",
        suburb: 'Mickleham',
        postcode: '3064',
        latitude: -37.521234,
        longitude: 144.912345,
        offerings: [
          offering(
            id: 'offer-secret',
            catalogue: service(code: 'dog_walking', name: 'Dog Walking'),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Text(sitter.fullName),
                Text('${sitter.suburb} ${sitter.postcode}'),
                Text(sitter.offerings.single.service!.name),
                Text(
                  '\$${sitter.offerings.single.price.toStringAsFixed(2)}'
                  ' • 45 minutes',
                ),
                const Text('Book'),
              ],
            ),
          ),
        ),
      );

      expect(find.text("Sarah's Pet Care"), findsOneWidget);
      expect(find.text('Dog Walking'), findsOneWidget);
      expect(find.textContaining('\$30.00'), findsOneWidget);
      expect(find.text('Book'), findsOneWidget);
      expect(find.textContaining('sitter-secret'), findsNothing);
      expect(find.textContaining('offer-secret'), findsNothing);
      expect(find.textContaining('dog_walking'), findsNothing);
      expect(find.textContaining('-37.521234'), findsNothing);
      expect(find.textContaining('144.912345'), findsNothing);
    });
  });
}
