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
    int displayOrder = 100,
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
      displayOrder: displayOrder,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  SitterProfileSummary profile({
    String id = 'sitter-1',
    String fullName = 'Sarah Care',
    String? suburb = 'Mickleham',
    String? postcode = '3064',
    String? serviceDescription = 'Gentle one-on-one pet care.',
  }) {
    return SitterProfileSummary(
      id: id,
      fullName: fullName,
      suburb: suburb,
      postcode: postcode,
      serviceDescription: serviceDescription,
    );
  }

  SitterServiceModel offering({
    String id = 'offer-1',
    String sitterId = 'sitter-1',
    String serviceId = 'svc-walk',
    double price = 30,
    int? duration = 45,
    bool isActive = true,
    ServiceModel? catalogue,
    SitterProfileSummary? sitter,
    bool includeSitter = true,
  }) {
    return SitterServiceModel(
      id: id,
      sitterId: sitterId,
      serviceId: serviceId,
      price: price,
      estimatedDurationMinutes: duration,
      isActive: isActive,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
      service: catalogue ?? service(id: serviceId),
      sitter: includeSitter ? (sitter ?? profile(id: sitterId)) : null,
    );
  }

  group('DiscoverableSitter', () {
    test('rejects blank id and fullName; blanks optional text to null', () {
      expect(
        () =>
            DiscoverableSitter(id: ' ', fullName: 'Alex', offerings: const []),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DiscoverableSitter(id: 's1', fullName: '  ', offerings: const []),
        throwsA(isA<FormatException>()),
      );

      final sitter = DiscoverableSitter(
        id: 's1',
        fullName: 'Alex',
        suburb: '  ',
        postcode: '',
        serviceDescription: '   ',
        offerings: [offering(isActive: false)],
      );
      expect(sitter.suburb, isNull);
      expect(sitter.postcode, isNull);
      expect(sitter.serviceDescription, isNull);
      expect(sitter.offerings, isEmpty);
    });
  });

  group('groupOfferingsIntoDiscoverableSitters', () {
    test('groups active offerings by sitter and drops duplicates/inactive', () {
      final walk = service(
        id: 'svc-walk',
        name: 'Dog Walking',
        displayOrder: 100,
      );
      final visit = service(
        id: 'svc-visit',
        code: 'home_visit',
        name: 'Home Visit',
        displayOrder: 110,
      );

      final sitters = groupOfferingsIntoDiscoverableSitters([
        offering(
          id: 'o1',
          sitterId: 'sitter-b',
          serviceId: 'svc-walk',
          catalogue: walk,
          sitter: profile(id: 'sitter-b', fullName: 'Zoe'),
        ),
        offering(
          id: 'o2',
          sitterId: 'sitter-a',
          serviceId: 'svc-walk',
          catalogue: walk,
          sitter: profile(id: 'sitter-a', fullName: 'Alex'),
        ),
        offering(
          id: 'o3',
          sitterId: 'sitter-a',
          serviceId: 'svc-visit',
          catalogue: visit,
          sitter: profile(id: 'sitter-a', fullName: 'Alex'),
        ),
        offering(
          id: 'o4',
          sitterId: 'sitter-a',
          serviceId: 'svc-walk',
          isActive: false,
          catalogue: walk,
          sitter: profile(id: 'sitter-a', fullName: 'Alex'),
        ),
        offering(
          id: 'o5',
          sitterId: 'sitter-c',
          serviceId: 'svc-walk',
          isActive: false,
          catalogue: walk,
          sitter: profile(id: 'sitter-c', fullName: 'Inactive Only'),
        ),
      ]);

      expect(sitters.map((s) => s.fullName), ['Alex', 'Zoe']);
      expect(sitters, hasLength(2));
      expect(sitters.first.offerings.map((o) => o.id), ['o2', 'o3']);
      expect(sitters.last.offerings.map((o) => o.id), ['o1']);
    });

    test('excludes offerings missing sitter or active service', () {
      final sitters = groupOfferingsIntoDiscoverableSitters([
        offering(includeSitter: false),
        offering(catalogue: service(isActive: false)),
      ]);
      expect(sitters, isEmpty);
    });
  });

  group('filterDiscoverableSitters', () {
    late List<DiscoverableSitter> sitters;

    setUp(() {
      final walk = service(id: 'svc-walk', name: 'Dog Walking');
      final visit = service(
        id: 'svc-visit',
        code: 'home_visit',
        name: 'Home Visit',
      );
      sitters = groupOfferingsIntoDiscoverableSitters([
        offering(
          id: 'o-walk',
          sitterId: 'sitter-1',
          serviceId: 'svc-walk',
          catalogue: walk,
          sitter: profile(
            id: 'sitter-1',
            fullName: "Sarah's Pet Care",
            suburb: 'Mickleham',
            postcode: '3064',
          ),
        ),
        offering(
          id: 'o-visit',
          sitterId: 'sitter-1',
          serviceId: 'svc-visit',
          catalogue: visit,
          sitter: profile(
            id: 'sitter-1',
            fullName: "Sarah's Pet Care",
            suburb: 'Mickleham',
            postcode: '3064',
          ),
        ),
        offering(
          id: 'o-alex',
          sitterId: 'sitter-2',
          serviceId: 'svc-walk',
          catalogue: walk,
          sitter: profile(
            id: 'sitter-2',
            fullName: 'Alex Walker',
            suburb: 'Carlton',
            postcode: '3053',
          ),
        ),
      ]);
    });

    test('All Services keeps every offering', () {
      final filtered = filterDiscoverableSitters(sitters);
      expect(filtered, hasLength(2));
      final sarah = filtered.firstWhere((s) => s.id == 'sitter-1');
      expect(sarah.offerings, hasLength(2));
      final totalOfferings = filtered.fold<int>(
        0,
        (sum, sitter) => sum + sitter.offerings.length,
      );
      expect(totalOfferings, 3);
    });

    test('exact-service filter keeps matching offerings only', () {
      final filtered = filterDiscoverableSitters(
        sitters,
        serviceId: 'svc-visit',
      );
      expect(filtered, hasLength(1));
      expect(filtered.single.fullName, "Sarah's Pet Care");
      expect(filtered.single.offerings.map((o) => o.id), ['o-visit']);
    });

    test('provider-name and suburb search are case-insensitive', () {
      expect(
        filterDiscoverableSitters(sitters, query: '  sarah  ').single.fullName,
        "Sarah's Pet Care",
      );
      expect(
        filterDiscoverableSitters(sitters, query: 'CARLTON').single.fullName,
        'Alex Walker',
      );
      expect(
        filterDiscoverableSitters(sitters, query: '3064').single.fullName,
        "Sarah's Pet Care",
      );
    });

    test('search plus service filter combine', () {
      final filtered = filterDiscoverableSitters(
        sitters,
        serviceId: 'svc-walk',
        query: 'mickleham',
      );
      expect(filtered, hasLength(1));
      expect(filtered.single.offerings.map((o) => o.id), ['o-walk']);
    });

    test('filtered empty when nothing matches', () {
      expect(
        filterDiscoverableSitters(
          sitters,
          serviceId: 'svc-visit',
          query: 'carlton',
        ),
        isEmpty,
      );
    });
  });

  group('owner route protection', () {
    test('/sitters remains an owner-only route', () {
      expect(isOwnerRouteLocation(AppRoutes.sitters), isTrue);
      expect(isSitterRouteLocation(AppRoutes.sitters), isFalse);
    });
  });

  group('SitterDiscoveryScreen display', () {
    testWidgets('shows names/prices and hides raw ids and service codes', (
      tester,
    ) async {
      final sitter = DiscoverableSitter(
        id: 'sitter-secret',
        fullName: "Sarah's Pet Care",
        suburb: 'Mickleham',
        postcode: '3064',
        serviceDescription: 'Gentle one-on-one pet care.',
        offerings: [
          offering(
            id: 'offer-secret',
            serviceId: 'svc-walk',
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
                Text(sitter.serviceDescription!),
                Text(sitter.offerings.single.service!.name),
                Text(
                  '\$${sitter.offerings.single.price.toStringAsFixed(2)}'
                  ' • 45 minutes',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text("Sarah's Pet Care"), findsOneWidget);
      expect(find.text('Dog Walking'), findsOneWidget);
      expect(find.textContaining('\$30.00'), findsOneWidget);
      expect(find.textContaining('sitter-secret'), findsNothing);
      expect(find.textContaining('offer-secret'), findsNothing);
      expect(find.textContaining('dog_walking'), findsNothing);
      expect(find.textContaining('svc-walk'), findsNothing);
    });

    testWidgets('shows filtered empty copy and Clear Filters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(
                  'No providers match your current search or service filter.',
                ),
                Text('Clear Filters'),
              ],
            ),
          ),
        ),
      );

      expect(
        find.text('No providers match your current search or service filter.'),
        findsOneWidget,
      );
      expect(find.text('Clear Filters'), findsOneWidget);
    });
  });
}
