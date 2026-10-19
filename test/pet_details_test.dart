import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/core/theme/app_theme.dart';
import 'package:paw_pal/features/pets/pet_details_screen.dart';
import 'package:paw_pal/features/pets/pet_list_screen.dart';
import 'package:paw_pal/features/pets/pet_model.dart';
import 'package:paw_pal/features/pets/pet_providers.dart';

void main() {
  final pet = PetModel(
    id: 'pet-1',
    ownerId: 'owner-1',
    name: 'Buddy',
    species: 'Dog',
    breed: 'Labrador',
    ageYears: 3,
    size: 'large',
    coatType: 'Short',
    medicalNotes: 'Allergic to chicken',
    behaviourNotes: 'Friendly with people',
    careNotes: 'Needs a walk after meals',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );

  test('pet details route is protected as an owner route', () {
    expect(isOwnerRouteLocation(AppRoutes.petDetails('pet-1')), isTrue);
    expect(isSitterRouteLocation(AppRoutes.petDetails('pet-1')), isFalse);
  });

  testWidgets('pet list opens details that show notes hidden on the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoutes.pets,
      routes: [
        GoRoute(
          path: AppRoutes.pets,
          builder: (context, state) => const PetListScreen(),
        ),
        GoRoute(
          path: '/pets/:petId/details',
          builder: (context, state) =>
              PetDetailsScreen(petId: state.pathParameters['petId']!),
        ),
        GoRoute(
          path: '/pets/:petId/edit',
          builder: (context, state) => const Text('Edit pet screen'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentOwnerPetsProvider.overrideWith((ref) async => [pet]),
          petByIdProvider('pet-1').overrideWith((ref) async => pet),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buddy'), findsOneWidget);
    expect(find.text('Allergic to chicken'), findsNothing);

    await tester.tap(find.text('Buddy'));
    await tester.pumpAndSettle();

    expect(find.text('Pet details'), findsOneWidget);
    expect(find.text('Allergic to chicken'), findsOneWidget);
    expect(find.text('Friendly with people'), findsOneWidget);
    expect(find.text('Needs a walk after meals'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('Short'), findsOneWidget);

    await tester.ensureVisible(find.text('Edit pet'));
    await tester.tap(find.text('Edit pet'));
    await tester.pumpAndSettle();

    expect(find.text('Edit pet screen'), findsOneWidget);
  });
}
