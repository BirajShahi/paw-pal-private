import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/features/ai_recommendation/ai_recommendation_providers.dart';
import 'package:paw_pal/features/ai_recommendation/ai_recommendation_repository.dart';
import 'package:paw_pal/features/ai_recommendation/ai_recommendation_request.dart';
import 'package:paw_pal/features/ai_recommendation/ai_recommendation_screen.dart';
import 'package:paw_pal/features/ai_recommendation/ai_service_recommendation_result.dart';
import 'package:paw_pal/features/pets/pet_model.dart';
import 'package:paw_pal/features/pets/pet_providers.dart';
import 'package:paw_pal/features/pets/pet_repository.dart';
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

class _TrackingPetRepository extends PetRepository {
  _TrackingPetRepository(super.client);

  int getCurrentOwnerPetsCalls = 0;

  @override
  Future<List<PetModel>> getCurrentOwnerPets() async {
    getCurrentOwnerPetsCalls++;
    throw const PetException('Should not call Supabase from the screen.');
  }
}

class _FakeAiRecommendationRepository extends AiRecommendationRepository {
  _FakeAiRecommendationRepository(super.client);

  int recommendCalls = 0;
  Object? errorToThrow;
  Duration delay = Duration.zero;
  List<Map<String, String>> sentBodies = [];

  AiServiceRecommendationResult result = AiServiceRecommendationResult(
    requestId: 'req-1',
    outcome: AiRecommendationOutcome.serviceRecommendation,
    primaryService: RecommendedServiceSummary(
      code: 'wash_dry_and_brush',
      name: 'Wash, Dry and Brush',
    ),
    additionalServices: [
      RecommendedServiceSummary(
        code: 'deshedding_treatment',
        name: 'De-shedding Treatment',
      ),
    ],
    reasoning:
        'The coat is muddy and shedding, so a wash with brushing is suitable.',
    sitterRequirements: ['Gentle dryer handling'],
    ownerAdvice: 'Book a wash and brush session this week.',
    safetyNotice:
        'PawPal provides pet-care service recommendations only and does not replace professional veterinary advice.',
  );

  @override
  Future<AiServiceRecommendationResult> recommendService(
    AiRecommendationRequest request,
  ) async {
    recommendCalls++;
    sentBodies.add(request.toMap());
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final error = errorToThrow;
    if (error != null) {
      if (error is Exception) {
        throw error;
      }
      throw Exception(error);
    }
    return result;
  }
}

PetModel _pet({
  String id = 'pet-1',
  String name = 'Buddy',
  String species = 'Dog',
  String? breed = 'Golden Retriever',
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

ServiceModel _service({
  String id = 'svc-1',
  String code = 'wash_dry_and_brush',
  String name = 'Wash, Dry and Brush',
}) {
  return ServiceModel(
    id: id,
    code: code,
    name: name,
    category: ServiceCategory.grooming,
    description: 'A cleaning and brushing service for muddy coats.',
    includedItems: const ['Wash'],
    recommendationTags: const ['muddy'],
    canBeAddOn: false,
    isActive: true,
    displayOrder: 10,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

SitterServiceModel _offering({
  String id = 'offer-1',
  double price = 30,
  int? duration = 45,
  String? notes = 'Friendly one-on-one walks with regular owner updates.',
  String sitterName = "Sarah's Pet Care",
  String? suburb = 'Mickleham',
  String? postcode = '3064',
  String? serviceDescription,
}) {
  return SitterServiceModel(
    id: id,
    sitterId: 'sitter-1',
    serviceId: 'svc-1',
    price: price,
    estimatedDurationMinutes: duration,
    serviceNotes: notes,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 2),
    updatedAt: DateTime.utc(2026, 1, 2),
    service: _service(),
    sitter: SitterProfileSummary(
      id: 'sitter-1',
      fullName: sitterName,
      suburb: suburb,
      postcode: postcode,
      serviceDescription: serviceDescription,
    ),
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

  group('AiRecommendationRequest', () {
    test('toMap contains exactly two permitted fields', () {
      final request = AiRecommendationRequest(
        petId: 'pet-1',
        ownerDescription:
            'My dog has a muddy coat and needs a full wash today.',
      );

      expect(request.toMap(), {
        'petId': 'pet-1',
        'ownerDescription':
            'My dog has a muddy coat and needs a full wash today.',
      });
      expect(request.toMap().keys, ['petId', 'ownerDescription']);
    });
  });

  group('AiServiceRecommendationResult', () {
    test('maps a service recommendation payload', () {
      final result = AiServiceRecommendationResult.fromMap({
        'requestId': 'req-1',
        'outcome': 'service_recommendation',
        'primaryService': {
          'code': 'wash_dry_and_brush',
          'name': 'Wash, Dry and Brush',
        },
        'additionalServices': [
          {'code': 'deshedding_treatment', 'name': 'De-shedding Treatment'},
        ],
        'reasoning':
            'The coat is muddy and shedding, so a wash with brushing is suitable.',
        'sitterRequirements': ['Gentle dryer handling'],
        'ownerAdvice': 'Book a wash and brush session this week.',
        'safetyNotice':
            'PawPal provides pet-care service recommendations only and does not replace professional veterinary advice.',
      });

      expect(result.outcome, AiRecommendationOutcome.serviceRecommendation);
      expect(result.primaryService?.name, 'Wash, Dry and Brush');
      expect(result.additionalServices, hasLength(1));
    });

    test('maps an urgent veterinary payload', () {
      final result = AiServiceRecommendationResult.fromMap({
        'requestId': 'req-2',
        'outcome': 'urgent_vet',
        'primaryService': null,
        'additionalServices': [],
        'reasoning':
            'The description reports breathing difficulty that needs urgent care.',
        'sitterRequirements': [],
        'ownerAdvice': 'Contact a veterinarian immediately.',
        'safetyNotice':
            'PawPal cannot assess or diagnose urgent medical conditions.',
      });

      expect(result.outcome, AiRecommendationOutcome.urgentVet);
      expect(result.primaryService, isNull);
      expect(result.additionalServices, isEmpty);
      expect(result.sitterRequirements, isEmpty);
    });

    test('rejects invalid outcome', () {
      expect(
        () => AiServiceRecommendationResult.fromMap({
          'requestId': 'req-1',
          'outcome': 'unknown',
          'primaryService': null,
          'additionalServices': [],
          'reasoning': 'A sufficiently long reasoning string for validation.',
          'sitterRequirements': [],
          'ownerAdvice': 'Please try again later.',
          'safetyNotice': 'Safety notice text.',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing primary service for service recommendation', () {
      expect(
        () => AiServiceRecommendationResult.fromMap({
          'requestId': 'req-1',
          'outcome': 'service_recommendation',
          'primaryService': null,
          'additionalServices': [],
          'reasoning': 'A sufficiently long reasoning string for validation.',
          'sitterRequirements': [],
          'ownerAdvice': 'Please book a suitable service soon.',
          'safetyNotice': 'Safety notice text.',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects primary service for urgent outcome', () {
      expect(
        () => AiServiceRecommendationResult.fromMap({
          'requestId': 'req-1',
          'outcome': 'urgent_vet',
          'primaryService': {
            'code': 'wash_dry_and_brush',
            'name': 'Wash, Dry and Brush',
          },
          'additionalServices': [],
          'reasoning': 'A sufficiently long reasoning string for validation.',
          'sitterRequirements': [],
          'ownerAdvice': 'Contact a veterinarian immediately.',
          'safetyNotice': 'Safety notice text.',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate additional service codes', () {
      expect(
        () => AiServiceRecommendationResult.fromMap({
          'requestId': 'req-1',
          'outcome': 'service_recommendation',
          'primaryService': {
            'code': 'wash_dry_and_brush',
            'name': 'Wash, Dry and Brush',
          },
          'additionalServices': [
            {'code': 'deshedding_treatment', 'name': 'De-shedding Treatment'},
            {'code': 'deshedding_treatment', 'name': 'De-shedding Treatment'},
          ],
          'reasoning': 'A sufficiently long reasoning string for validation.',
          'sitterRequirements': [],
          'ownerAdvice': 'Please book a suitable service soon.',
          'safetyNotice': 'Safety notice text.',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AiRecommendationScreen', () {
    late _TrackingPetRepository petRepository;
    late _FakeAiRecommendationRepository aiRepository;
    late List<String> watchedMatchCodes;
    late int matchLoads;
    Object? matchError;
    Duration matchDelay = Duration.zero;
    List<SitterServiceModel> matchOfferings = const [];

    Future<void> pumpScreen(
      WidgetTester tester, {
      required List<PetModel> pets,
      Object? aiError,
      Duration aiDelay = Duration.zero,
      AiServiceRecommendationResult? result,
      List<SitterServiceModel>? offerings,
      Object? offeringsError,
      Duration offeringsDelay = Duration.zero,
    }) async {
      petRepository = _TrackingPetRepository(Supabase.instance.client);
      aiRepository = _FakeAiRecommendationRepository(Supabase.instance.client)
        ..errorToThrow = aiError
        ..delay = aiDelay;
      if (result != null) {
        aiRepository.result = result;
      }

      watchedMatchCodes = <String>[];
      matchLoads = 0;
      matchError = offeringsError;
      matchDelay = offeringsDelay;
      matchOfferings = offerings ?? const [];

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: AppRoutes.aiRecommendation,
        routes: [
          GoRoute(
            path: AppRoutes.aiRecommendation,
            builder: (context, state) => const AiRecommendationScreen(),
          ),
          GoRoute(
            path: AppRoutes.petNew,
            builder: (context, state) =>
                const Scaffold(body: Text('Add pet form')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentOwnerPetsProvider.overrideWith((ref) async => pets),
            petRepositoryProvider.overrideWithValue(petRepository),
            aiRecommendationRepositoryProvider.overrideWithValue(aiRepository),
            activeSitterMatchesByServiceCodeProvider.overrideWith((
              ref,
              code,
            ) async {
              watchedMatchCodes.add(code);
              matchLoads++;
              if (matchDelay > Duration.zero) {
                await Future<void>.delayed(matchDelay);
              }
              final error = matchError;
              if (error != null) {
                if (error is Exception) throw error;
                throw Exception(error);
              }
              return matchOfferings;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buddy — Dog · Golden Retriever').last);
      await tester.pumpAndSettle();

      const description =
          'My Golden Retriever has a muddy coat and needs a wash today.';
      await tester.enterText(find.byType(TextFormField), description);
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'Find the Best Service');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
    }

    testWidgets('shows no-pet empty state', (tester) async {
      await pumpScreen(tester, pets: const []);

      expect(find.text('Add a pet to get started'), findsOneWidget);
      expect(find.text('Find the Best Service'), findsNothing);
    });

    testWidgets('repository sends exactly petId and ownerDescription', (
      tester,
    ) async {
      await pumpScreen(tester, pets: [_pet()], offerings: const []);
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(aiRepository.recommendCalls, 1);
      expect(aiRepository.sentBodies.single.keys.toList(), [
        'petId',
        'ownerDescription',
      ]);
      expect(aiRepository.sentBodies.single['petId'], 'pet-1');
      expect(find.text('Wash, Dry and Brush'), findsWidgets);
      expect(find.text('Recommended Service'), findsOneWidget);
      expect(find.textContaining('wash_dry_and_brush'), findsNothing);
    });

    testWidgets('shows matching providers for service recommendation', (
      tester,
    ) async {
      await pumpScreen(tester, pets: [_pet()], offerings: [_offering()]);
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Providers offering this service'), findsOneWidget);
      expect(watchedMatchCodes, ['wash_dry_and_brush']);
      expect(find.text("Sarah's Pet Care"), findsOneWidget);
      expect(find.text('Mickleham 3064'), findsOneWidget);
      expect(find.text(r'$30.00'), findsOneWidget);
      expect(find.text('Estimated duration: 45 minutes'), findsOneWidget);
      expect(
        find.text('Friendly one-on-one walks with regular owner updates.'),
        findsOneWidget,
      );
    });

    testWidgets('hides provider section for urgent veterinary results', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        pets: [_pet()],
        result: AiServiceRecommendationResult(
          requestId: 'req-urgent',
          outcome: AiRecommendationOutcome.urgentVet,
          primaryService: null,
          additionalServices: const [],
          reasoning:
              'Breathing difficulty is an urgent symptom needing veterinary care.',
          sitterRequirements: const [],
          ownerAdvice: 'Contact a veterinarian immediately.',
          safetyNotice:
              'PawPal cannot assess or diagnose urgent medical conditions.',
        ),
        offerings: [_offering()],
      );
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Contact a veterinarian immediately'), findsWidgets);
      expect(find.text('Providers offering this service'), findsNothing);
      expect(watchedMatchCodes, isEmpty);
    });

    testWidgets('loading providers does not hide the recommendation', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        pets: [_pet()],
        offeringsDelay: const Duration(milliseconds: 300),
        offerings: [_offering()],
      );
      await fillAndSubmit(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Recommended Service'), findsOneWidget);
      expect(find.text('Wash, Dry and Brush'), findsWidgets);
      expect(find.text('Loading providers…'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text("Sarah's Pet Care"), findsOneWidget);
    });

    testWidgets('shows empty provider state when none match', (tester) async {
      await pumpScreen(tester, pets: [_pet()], offerings: const []);
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('No providers currently offer this exact service.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'try again later or review the recommended service',
        ),
        findsOneWidget,
      );
    });

    testWidgets('retry refreshes only the matching provider', (tester) async {
      await pumpScreen(
        tester,
        pets: [_pet()],
        offeringsError: Exception('Could not load providers.'),
      );
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Recommended Service'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      final loadsBeforeRetry = matchLoads;

      matchError = null;
      matchOfferings = [_offering()];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(matchLoads, greaterThan(loadsBeforeRetry));
      expect(watchedMatchCodes.toSet(), {'wash_dry_and_brush'});
      expect(find.text("Sarah's Pet Care"), findsOneWidget);
      expect(aiRepository.recommendCalls, 1);
    });

    testWidgets('new recommendation clears previous provider results', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        pets: [_pet()],
        offerings: [_offering(sitterName: 'Old Provider')],
      );
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Old Provider'), findsOneWidget);

      aiRepository.result = AiServiceRecommendationResult(
        requestId: 'req-2',
        outcome: AiRecommendationOutcome.serviceRecommendation,
        primaryService: RecommendedServiceSummary(
          code: 'dog_walking',
          name: 'Dog Walking',
        ),
        additionalServices: const [],
        reasoning:
            'The pet needs regular outdoor exercise with a trusted walker.',
        sitterRequirements: const ['Reliable walking routine'],
        ownerAdvice: 'Book a walking session this week.',
        safetyNotice:
            'PawPal provides pet-care service recommendations only and does not replace professional veterinary advice.',
      );
      matchOfferings = [
        _offering(sitterName: 'New Walker', notes: null, duration: 60),
      ];

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Old Provider'), findsNothing);
      expect(find.text('New Walker'), findsOneWidget);
      expect(find.text('Dog Walking'), findsWidgets);
      expect(watchedMatchCodes.contains('dog_walking'), isTrue);
    });

    testWidgets('prevents double submission while processing', (tester) async {
      await pumpScreen(
        tester,
        pets: [_pet()],
        aiDelay: const Duration(milliseconds: 300),
        offerings: const [],
      );
      await fillAndSubmit(tester);
      await tester.pump(const Duration(milliseconds: 50));

      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(aiRepository.recommendCalls, 1);
    });

    testWidgets('shows backend error without clearing the form', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        pets: [_pet()],
        aiError: const AiRecommendationException(
          'PawPal could not generate a recommendation right now. Please try again.',
        ),
        offerings: const [],
      );

      const description =
          'My Golden Retriever has a muddy coat and needs a wash today.';
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'PawPal could not generate a recommendation right now. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.text(description), findsOneWidget);
      expect(find.text('Buddy — Dog · Golden Retriever'), findsOneWidget);
      expect(aiRepository.recommendCalls, 1);
      expect(watchedMatchCodes, isEmpty);
    });

    testWidgets('shows urgent veterinary warning card', (tester) async {
      await pumpScreen(
        tester,
        pets: [_pet()],
        result: AiServiceRecommendationResult(
          requestId: 'req-urgent',
          outcome: AiRecommendationOutcome.urgentVet,
          primaryService: null,
          additionalServices: const [],
          reasoning:
              'Breathing difficulty is an urgent symptom needing veterinary care.',
          sitterRequirements: const [],
          ownerAdvice: 'Contact a veterinarian immediately.',
          safetyNotice:
              'PawPal cannot assess or diagnose urgent medical conditions.',
        ),
        offerings: const [],
      );
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Contact a veterinarian immediately'), findsWidgets);
      expect(find.text('Recommended Service'), findsNothing);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
