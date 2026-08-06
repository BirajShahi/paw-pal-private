import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'pet_model.dart';
import 'pet_repository.dart';

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository(Supabase.instance.client);
});

/// Pets owned by the signed-in user. Refresh with `ref.invalidate`.
final currentOwnerPetsProvider = FutureProvider<List<PetModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const PetException('You are not signed in. Please log in again.');
  }

  return ref.read(petRepositoryProvider).getCurrentOwnerPets();
});

/// Single pet by ID for the signed-in owner. Refresh with `ref.invalidate`.
final petByIdProvider = FutureProvider.family<PetModel, String>((
  ref,
  petId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const PetException('You are not signed in. Please log in again.');
  }

  return ref.read(petRepositoryProvider).getPetById(petId);
});
