import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/features/services/add_sitter_service_screen.dart';
import 'package:paw_pal/features/services/edit_sitter_service_screen.dart';
import 'package:paw_pal/features/services/service_category.dart';
import 'package:paw_pal/features/services/service_model.dart';
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

ServiceModel _service({String id = 'svc-1', String name = 'Full Grooming'}) {
  return ServiceModel(
    id: id,
    code: 'full_grooming',
    name: name,
    category: ServiceCategory.grooming,
    description: 'A complete grooming service for pets that need cleaning.',
    includedItems: const ['Wash and shampoo', 'Blow-dry'],
    recommendationTags: const ['dirty coat'],
    canBeAddOn: false,
    isActive: true,
    displayOrder: 10,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

SitterServiceModel _offering({
  String id = 'offer-1',
  double price = 45.5,
  int? duration = 60,
  String? notes = 'Gentle handling',
  bool isActive = true,
}) {
  final service = _service();
  return SitterServiceModel(
    id: id,
    sitterId: 'sitter-1',
    serviceId: service.id,
    price: price,
    estimatedDurationMinutes: duration,
    serviceNotes: notes,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 1, 2),
    updatedAt: DateTime.utc(2026, 1, 3),
    service: service,
  );
}

class _RecordingSitterServiceRepository extends SitterServiceRepository {
  _RecordingSitterServiceRepository(super.client);

  int updateCalls = 0;
  int deleteCalls = 0;
  int byIdLoads = 0;
  Object? throwOnUpdate;
  Object? throwOnDelete;
  final List<Map<String, Object?>> updateArgs = [];
  SitterServiceModel offering = _offering();

  @override
  Future<SitterServiceModel> getSitterServiceById(String offeringId) async {
    byIdLoads++;
    if (offeringId != offering.id) {
      throw const SitterServiceException('Service offering not found.');
    }
    return offering;
  }

  @override
  Future<SitterServiceModel> updateSitterService({
    required String offeringId,
    required double price,
    int? estimatedDurationMinutes,
    String? serviceNotes,
    required bool isActive,
  }) async {
    updateCalls++;
    updateArgs.add({
      'offeringId': offeringId,
      'price': price,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'serviceNotes': serviceNotes,
      'isActive': isActive,
    });

    if (throwOnUpdate != null) {
      throw throwOnUpdate!;
    }

    offering = SitterServiceModel(
      id: offering.id,
      sitterId: offering.sitterId,
      serviceId: offering.serviceId,
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
      serviceNotes: serviceNotes,
      isActive: isActive,
      createdAt: offering.createdAt,
      updatedAt: DateTime.utc(2026, 1, 4),
      service: offering.service,
    );
    return offering;
  }

  @override
  Future<void> deleteSitterService(String offeringId) async {
    deleteCalls++;
    if (throwOnDelete != null) {
      throw throwOnDelete!;
    }
  }
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

  group('edit validators', () {
    test('validates price and duration', () {
      expect(validateSitterServicePrice(''), 'Price is required');
      expect(
        validateSitterServicePrice('0'),
        'Price must be greater than 0 and at most 1000',
      );
      expect(validateSitterServicePrice('45.50'), isNull);
      expect(validateSitterServiceDuration(''), isNull);
      expect(
        validateSitterServiceDuration('14'),
        'Duration must be between 15 and 1440 minutes',
      );
      expect(validateSitterServiceDuration('60'), isNull);
    });
  });

  group('EditSitterServiceScreen', () {
    late _RecordingSitterServiceRepository repository;

    Future<void> pumpScreen(WidgetTester tester) async {
      repository = _RecordingSitterServiceRepository(Supabase.instance.client);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: AppRoutes.sitterServiceEdit('offer-1'),
        routes: [
          GoRoute(
            path: '/sitter-services/:offeringId/edit',
            builder: (context, state) {
              final offeringId = state.pathParameters['offeringId']!;
              return EditSitterServiceScreen(offeringId: offeringId);
            },
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
            sitterServiceRepositoryProvider.overrideWithValue(repository),
            sitterServiceByIdProvider.overrideWith((ref, offeringId) async {
              return repository.getSitterServiceById(offeringId);
            }),
            currentSitterServicesProvider.overrideWith((ref) async {
              return [repository.offering];
            }),
            activeOfferingsForServiceProvider.overrideWith((
              ref,
              serviceId,
            ) async {
              return const [];
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'pre-fills existing values and keeps service identity read-only',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('Full Grooming'), findsWidgets);
        expect(find.text('Grooming'), findsOneWidget);
        expect(
          find.text('A complete grooming service for pets that need cleaning.'),
          findsOneWidget,
        );
        expect(find.text('• Wash and shampoo'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.text('45.5'), findsOneWidget);
        expect(find.text('60'), findsOneWidget);
        expect(find.text('Gentle handling'), findsOneWidget);
        expect(find.text('Active — visible to pet owners'), findsOneWidget);
      },
    );

    testWidgets('save calls repository once with active status and refreshes', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '55');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final loadsBefore = repository.byIdLoads;
      final button = find.widgetWithText(FilledButton, 'Save changes');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.updateArgs.single['offeringId'], 'offer-1');
      expect(repository.updateArgs.single['price'], 55.0);
      expect(repository.updateArgs.single['isActive'], isFalse);
      expect(repository.byIdLoads, greaterThan(loadsBefore));
      expect(find.text('My services list'), findsOneWidget);
      expect(find.text('Full Grooming was updated.'), findsOneWidget);
    });

    testWidgets('save failure displays an error', (tester) async {
      await pumpScreen(tester);
      repository.throwOnUpdate = const SitterServiceException(
        'Could not update this service.',
      );

      final button = find.widgetWithText(FilledButton, 'Save changes');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Could not update this service.'), findsOneWidget);
      expect(repository.updateCalls, 1);
      expect(find.text('My services list'), findsNothing);
    });

    testWidgets('cancelled deletion does not delete', (tester) async {
      await pumpScreen(tester);

      final deleteButton = find.widgetWithText(
        OutlinedButton,
        'Delete Service',
      );
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Remove Full Grooming?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, 0);
      expect(find.text('Edit service'), findsOneWidget);
    });

    testWidgets('confirmed deletion calls repository once and refreshes', (
      tester,
    ) async {
      await pumpScreen(tester);

      final loadsBefore = repository.byIdLoads;
      final deleteButton = find.widgetWithText(
        OutlinedButton,
        'Delete Service',
      );
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove Service'));
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, 1);
      expect(repository.byIdLoads, greaterThan(loadsBefore));
      expect(find.text('My services list'), findsOneWidget);
      expect(find.text('Full Grooming was removed.'), findsOneWidget);
    });
  });
}
