import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/features/ai_recommendation/ai_recommendation_request.dart';
import 'package:paw_pal/features/ai_recommendation/ai_recommendation_screen.dart';
import 'package:paw_pal/features/pets/pet_model.dart';
import 'package:paw_pal/features/pets/pet_providers.dart';
import 'package:paw_pal/features/pets/pet_repository.dart';
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
    test('creates a valid request and trims description', () {
      final request = AiRecommendationRequest(
        petId: '  pet-1  ',
        ownerDescription:
            '  My dog has a muddy coat and needs a full wash today.  ',
      );

      expect(request.petId, 'pet-1');
      expect(
        request.ownerDescription,
        'My dog has a muddy coat and needs a full wash today.',
      );
    });

    test('rejects blank pet id', () {
      expect(
        () => AiRecommendationRequest(
          petId: '   ',
          ownerDescription: 'My dog has a muddy coat and needs washing today.',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects whitespace-only description', () {
      expect(
        validateAiRecommendationDescription('          '),
        'Please describe what your pet needs today',
      );
      expect(
        () => AiRecommendationRequest(
          petId: 'pet-1',
          ownerDescription: '                    ',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects description below minimum length', () {
      expect(
        validateAiRecommendationDescription('Too short'),
        'Please enter at least 20 characters',
      );
      expect(
        () => AiRecommendationRequest(
          petId: 'pet-1',
          ownerDescription: 'Too short for AI',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects description above maximum length', () {
      final tooLong = 'a' * 1001;
      expect(
        validateAiRecommendationDescription(tooLong),
        'Description may contain up to 1000 characters',
      );
      expect(
        () =>
            AiRecommendationRequest(petId: 'pet-1', ownerDescription: tooLong),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AiRecommendationScreen', () {
    late _TrackingPetRepository petRepository;

    Future<void> pumpScreen(
      WidgetTester tester, {
      required List<PetModel> pets,
    }) async {
      petRepository = _TrackingPetRepository(Supabase.instance.client);

      tester.view.physicalSize = const Size(800, 1600);
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
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows no-pet empty state', (tester) async {
      await pumpScreen(tester, pets: const []);

      expect(find.text('Add a pet to get started'), findsOneWidget);
      expect(
        find.text(
          'A pet profile is required for personalised service recommendations.',
        ),
        findsOneWidget,
      );
      expect(find.text('Find the Best Service'), findsNothing);

      await tester.tap(find.text('Add a Pet'));
      await tester.pumpAndSettle();
      expect(find.text('Add pet form'), findsOneWidget);
    });

    testWidgets('allows pet selection and shows breed when available', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        pets: [
          _pet(),
          _pet(id: 'pet-2', name: 'Mochi', species: 'Cat', breed: null),
        ],
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Buddy — Dog · Golden Retriever'), findsWidgets);
      expect(find.text('Mochi — Cat'), findsWidgets);

      await tester.tap(find.text('Buddy — Dog · Golden Retriever').last);
      await tester.pumpAndSettle();
      expect(find.text('Buddy — Dog · Golden Retriever'), findsOneWidget);
    });

    testWidgets('submit builds an in-memory request without Supabase', (
      tester,
    ) async {
      await pumpScreen(tester, pets: [_pet()]);

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
      await tester.pumpAndSettle();

      expect(petRepository.getCurrentOwnerPetsCalls, 0);
      expect(find.textContaining('ready for AI analysis'), findsOneWidget);
      expect(find.text(description), findsOneWidget);
      expect(find.textContaining('Full Grooming'), findsNothing);
    });
  });
}
