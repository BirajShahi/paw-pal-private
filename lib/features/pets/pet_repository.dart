import 'package:supabase_flutter/supabase_flutter.dart';

import 'pet_model.dart';

/// Thrown when a pet cannot be loaded or an update is invalid.
class PetException implements Exception {
  const PetException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _allowedSizes = <String>{'small', 'medium', 'large'};

const _petSelect =
    'id, owner_id, name, species, breed, age_years, size, coat_type, '
    'medical_notes, behaviour_notes, care_notes, created_at, updated_at';

/// Supabase access for `public.pets`.
class PetRepository {
  PetRepository(this._client);

  final SupabaseClient _client;

  Future<List<PetModel>> getCurrentOwnerPets() async {
    final userId = _requireUserId();

    final rows = await _client
        .from('pets')
        .select(_petSelect)
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return [
      for (final row in rows as List<dynamic>)
        PetModel.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<PetModel> getPetById(String petId) async {
    final userId = _requireUserId();

    final row = await _client
        .from('pets')
        .select(_petSelect)
        .eq('id', petId)
        .eq('owner_id', userId)
        .maybeSingle();

    if (row == null) {
      throw const PetException('Pet not found.');
    }

    try {
      return PetModel.fromMap(row);
    } on FormatException catch (error) {
      throw PetException(error.message);
    }
  }

  Future<PetModel> createPet({
    required String name,
    required String species,
    String? breed,
    double? ageYears,
    String? size,
    String? coatType,
    String? medicalNotes,
    String? behaviourNotes,
    String? careNotes,
  }) async {
    final userId = _requireUserId();
    final payload = _validatedPayload(
      name: name,
      species: species,
      breed: breed,
      ageYears: ageYears,
      size: size,
      coatType: coatType,
      medicalNotes: medicalNotes,
      behaviourNotes: behaviourNotes,
      careNotes: careNotes,
    )..['owner_id'] = userId;

    final row = await _client
        .from('pets')
        .insert(payload)
        .select(_petSelect)
        .single();

    try {
      return PetModel.fromMap(row);
    } on FormatException catch (error) {
      throw PetException(error.message);
    }
  }

  Future<PetModel> updatePet({
    required String petId,
    required String name,
    required String species,
    String? breed,
    double? ageYears,
    String? size,
    String? coatType,
    String? medicalNotes,
    String? behaviourNotes,
    String? careNotes,
  }) async {
    final userId = _requireUserId();
    final payload = _validatedPayload(
      name: name,
      species: species,
      breed: breed,
      ageYears: ageYears,
      size: size,
      coatType: coatType,
      medicalNotes: medicalNotes,
      behaviourNotes: behaviourNotes,
      careNotes: careNotes,
    );

    final row = await _client
        .from('pets')
        .update(payload)
        .eq('id', petId)
        .eq('owner_id', userId)
        .select(_petSelect)
        .maybeSingle();

    if (row == null) {
      throw const PetException('Pet not found.');
    }

    try {
      return PetModel.fromMap(row);
    } on FormatException catch (error) {
      throw PetException(error.message);
    }
  }

  Future<void> deletePet(String petId) async {
    final userId = _requireUserId();

    await _client.from('pets').delete().eq('id', petId).eq('owner_id', userId);
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const PetException('You are not signed in. Please log in again.');
    }
    return user.id;
  }

  /// Exposed for unit tests without a live Supabase client.
  static Map<String, dynamic> validatePetFields({
    required String name,
    required String species,
    String? breed,
    double? ageYears,
    String? size,
    String? coatType,
    String? medicalNotes,
    String? behaviourNotes,
    String? careNotes,
  }) {
    return _validatedPayload(
      name: name,
      species: species,
      breed: breed,
      ageYears: ageYears,
      size: size,
      coatType: coatType,
      medicalNotes: medicalNotes,
      behaviourNotes: behaviourNotes,
      careNotes: careNotes,
    );
  }

  static Map<String, dynamic> _validatedPayload({
    required String name,
    required String species,
    String? breed,
    double? ageYears,
    String? size,
    String? coatType,
    String? medicalNotes,
    String? behaviourNotes,
    String? careNotes,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.length < 2 || trimmedName.length > 60) {
      throw const PetException('Name must be between 2 and 60 characters.');
    }

    final trimmedSpecies = species.trim();
    if (trimmedSpecies.length < 2 || trimmedSpecies.length > 40) {
      throw const PetException('Species must be between 2 and 40 characters.');
    }

    final trimmedBreed = _trimOrNull(breed);
    if (trimmedBreed != null && trimmedBreed.length > 80) {
      throw const PetException('Breed may contain up to 80 characters.');
    }

    if (ageYears != null && (ageYears < 0 || ageYears > 100)) {
      throw const PetException('Age must be between 0 and 100.');
    }

    final trimmedSize = _trimOrNull(size);
    if (trimmedSize != null && !_allowedSizes.contains(trimmedSize)) {
      throw const PetException('Size must be small, medium or large.');
    }

    final trimmedCoatType = _trimOrNull(coatType);
    if (trimmedCoatType != null && trimmedCoatType.length > 80) {
      throw const PetException('Coat type may contain up to 80 characters.');
    }

    final trimmedMedical = _trimOrNull(medicalNotes);
    if (trimmedMedical != null && trimmedMedical.length > 1000) {
      throw const PetException(
        'Medical notes may contain up to 1000 characters.',
      );
    }

    final trimmedBehaviour = _trimOrNull(behaviourNotes);
    if (trimmedBehaviour != null && trimmedBehaviour.length > 1000) {
      throw const PetException(
        'Behaviour notes may contain up to 1000 characters.',
      );
    }

    final trimmedCare = _trimOrNull(careNotes);
    if (trimmedCare != null && trimmedCare.length > 1000) {
      throw const PetException('Care notes may contain up to 1000 characters.');
    }

    return {
      'name': trimmedName,
      'species': trimmedSpecies,
      'breed': trimmedBreed,
      'age_years': ageYears,
      'size': trimmedSize,
      'coat_type': trimmedCoatType,
      'medical_notes': trimmedMedical,
      'behaviour_notes': trimmedBehaviour,
      'care_notes': trimmedCare,
    };
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
