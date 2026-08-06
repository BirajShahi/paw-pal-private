import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/features/services/add_sitter_service_screen.dart';
import 'package:paw_pal/features/services/service_category.dart';
import 'package:paw_pal/features/services/service_model.dart';
import 'package:paw_pal/features/services/service_providers.dart';
import 'package:paw_pal/features/services/sitter_service_model.dart';
import 'package:paw_pal/features/services/sitter_service_providers.dart';
import 'package:paw_pal/features/services/sitter_service_repository.dart';
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

class _RecordingSitterServiceRepository extends SitterServiceRepository {
  _RecordingSitterServiceRepository(super.client);

  int createCalls = 0;
  Object? throwOnCreate;
  Duration delay = Duration.zero;
  final List<Map<String, Object?>> createArgs = [];

  @override
  Future<SitterServiceModel> createSitterService({
    required String serviceId,
    required double price,
    int? estimatedDurationMinutes,
    String? serviceNotes,
  }) async {
    createCalls++;
    createArgs.add({
      'serviceId': serviceId,
      'price': price,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'serviceNotes': serviceNotes,
    });

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (throwOnCreate != null) {
      throw throwOnCreate!;
    }

    return SitterServiceModel(
      id: 'offer-new',
      sitterId: 'sitter-1',
      serviceId: serviceId,
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
      serviceNotes: serviceNotes,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
      service: _service(serviceId),
    );
  }
}

ServiceModel _service(
  String id, {
  String name = 'Full Grooming',
  ServiceCategory category = ServiceCategory.grooming,
  int displayOrder = 10,
}) {
  return ServiceModel(
    id: id,
    code: 'code_$id',
    name: name,
    category: category,
    description: 'Catalogue description for $name.',
    includedItems: const ['Wash and shampoo'],
    recommendationTags: const ['dirty coat'],
    canBeAddOn: false,
    isActive: true,
    displayOrder: displayOrder,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

SitterServiceModel _offering({
  required String serviceId,
  bool isActive = true,
}) {
  return SitterServiceModel(
    id: 'offer-$serviceId',
    sitterId: 'sitter-1',
    serviceId: serviceId,
    price: 40,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 1, 2),
    updatedAt: DateTime.utc(2026, 1, 2),
    service: _service(serviceId),
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

  group('availableCatalogueServices', () {
    test('excludes services the sitter already offers, including inactive', () {
      final catalogue = [
        _service('svc-1', name: 'Full Grooming', displayOrder: 10),
        _service(
          'svc-2',
          name: 'Dog Walking',
          category: ServiceCategory.walking,
          displayOrder: 20,
        ),
        _service(
          'svc-3',
          name: 'Home Visit',
          category: ServiceCategory.homeCare,
          displayOrder: 30,
        ),
      ];
      final offerings = [
        _offering(serviceId: 'svc-1'),
        _offering(serviceId: 'svc-3', isActive: false),
      ];

      final available = availableCatalogueServices(
        catalogue: catalogue,
        offerings: offerings,
      );

      expect(available.map((s) => s.id), ['svc-2']);
    });

    test('preserves catalogue order from activeServicesProvider', () {
      final catalogue = [
        _service('a', name: 'A', displayOrder: 1),
        _service('b', name: 'B', displayOrder: 2),
        _service('c', name: 'C', displayOrder: 3),
      ];

      final available = availableCatalogueServices(
        catalogue: catalogue,
        offerings: [_offering(serviceId: 'b')],
      );

      expect(available.map((s) => s.id), ['a', 'c']);
    });
  });

  group('form validators', () {
    test('validates price', () {
      expect(validateSitterServicePrice(null), 'Price is required');
      expect(validateSitterServicePrice(''), 'Price is required');
      expect(validateSitterServicePrice('abc'), 'Enter a valid number');
      expect(
        validateSitterServicePrice('0'),
        'Price must be greater than 0 and at most 1000',
      );
      expect(
        validateSitterServicePrice('1001'),
        'Price must be greater than 0 and at most 1000',
      );
      expect(validateSitterServicePrice('20'), isNull);
      expect(validateSitterServicePrice('45.50'), isNull);
      expect(validateSitterServicePrice('120'), isNull);
    });

    test('validates duration', () {
      expect(validateSitterServiceDuration(null), isNull);
      expect(validateSitterServiceDuration(''), isNull);
      expect(validateSitterServiceDuration('  '), isNull);
      expect(validateSitterServiceDuration('12.5'), 'Enter whole minutes only');
      expect(
        validateSitterServiceDuration('14'),
        'Duration must be between 15 and 1440 minutes',
      );
      expect(
        validateSitterServiceDuration('1441'),
        'Duration must be between 15 and 1440 minutes',
      );
      expect(validateSitterServiceDuration('30'), isNull);
      expect(validateSitterServiceDuration('60'), isNull);
      expect(validateSitterServiceDuration('120'), isNull);
    });

    test('maps duplicate errors', () {
      expect(
        isDuplicateSitterServiceError(Exception('duplicate key value 23505')),
        isTrue,
      );
      expect(isDuplicateSitterServiceError(Exception('network')), isFalse);
    });
  });

  group('AddSitterServiceScreen', () {
    late _RecordingSitterServiceRepository repository;
    late int offeringsLoads;

    Future<void> pumpScreen(
      WidgetTester tester, {
      required List<ServiceModel> catalogue,
      required List<SitterServiceModel> offerings,
    }) async {
      repository = _RecordingSitterServiceRepository(Supabase.instance.client);
      offeringsLoads = 0;

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: AppRoutes.sitterServiceNew,
        routes: [
          GoRoute(
            path: AppRoutes.sitterServiceNew,
            builder: (context, state) => const AddSitterServiceScreen(),
          ),
          GoRoute(
            path: AppRoutes.sitterServices,
            builder: (context, state) =>
                const Scaffold(body: Text('My services list')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServicesProvider.overrideWith((ref) async => catalogue),
            currentSitterServicesProvider.overrideWith((ref) async {
              offeringsLoads++;
              return offerings;
            }),
            sitterServiceRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> selectService(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> tapAddService(WidgetTester tester) async {
      final button = find.widgetWithText(FilledButton, 'Add Service');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
    }

    testWidgets('excludes existing offerings from the dropdown', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        catalogue: [
          _service('svc-1', name: 'Full Grooming'),
          _service(
            'svc-2',
            name: 'Dog Walking',
            category: ServiceCategory.walking,
          ),
        ],
        offerings: [_offering(serviceId: 'svc-1', isActive: false)],
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Dog Walking — Dog Walking'), findsWidgets);
      expect(find.text('Full Grooming — Grooming'), findsNothing);
    });

    testWidgets('shows empty state when every service is offered', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        catalogue: [_service('svc-1')],
        offerings: [_offering(serviceId: 'svc-1')],
      );

      expect(
        find.text('You have already added every available PawPal service.'),
        findsOneWidget,
      );
      expect(find.text('Add Service'), findsNothing);
    });

    testWidgets('submits once and refreshes the service list on success', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        catalogue: [
          _service(
            'svc-2',
            name: 'Dog Walking',
            category: ServiceCategory.walking,
          ),
        ],
        offerings: const [],
      );

      await selectService(tester, 'Dog Walking — Dog Walking');

      await tester.enterText(find.byType(TextFormField).at(0), '45.50');
      await tester.enterText(find.byType(TextFormField).at(1), '60');
      await tester.enterText(find.byType(TextFormField).at(2), '  Gentle  ');

      final loadsBeforeSubmit = offeringsLoads;
      await tapAddService(tester);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.createArgs.single['serviceId'], 'svc-2');
      expect(repository.createArgs.single['price'], 45.5);
      expect(repository.createArgs.single['estimatedDurationMinutes'], 60);
      expect(repository.createArgs.single['serviceNotes'], 'Gentle');
      expect(offeringsLoads, greaterThan(loadsBeforeSubmit));
      expect(find.text('My services list'), findsOneWidget);
      expect(
        find.text('Dog Walking was added to your services.'),
        findsOneWidget,
      );
    });

    testWidgets('prevents double submission', (tester) async {
      await pumpScreen(
        tester,
        catalogue: [_service('svc-2', name: 'Dog Walking')],
        offerings: const [],
      );
      repository.delay = const Duration(milliseconds: 400);

      await selectService(tester, 'Dog Walking — Grooming');
      await tester.enterText(find.byType(TextFormField).at(0), '30');

      await tapAddService(tester);
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
    });

    testWidgets('displays an error when creation fails', (tester) async {
      await pumpScreen(
        tester,
        catalogue: [_service('svc-2', name: 'Dog Walking')],
        offerings: const [],
      );
      repository.throwOnCreate = Exception(
        'duplicate key value violates unique 23505',
      );

      await selectService(tester, 'Dog Walking — Grooming');
      await tester.enterText(find.byType(TextFormField).at(0), '30');
      await tapAddService(tester);
      await tester.pumpAndSettle();

      expect(find.text('You already offer this service.'), findsOneWidget);
      expect(repository.createCalls, 1);
    });
  });
}
