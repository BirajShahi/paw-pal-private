import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/features/pets/pet_model.dart';
import 'package:paw_pal/features/pets/pet_repository.dart';

void main() {
  group('PetModel.fromMap', () {
    test('maps a valid pets row', () {
      final pet = PetModel.fromMap({
        'id': 'pet-1',
        'owner_id': 'owner-1',
        'name': 'Buddy',
        'species': 'Dog',
        'breed': 'Labrador',
        'age_years': 3.5,
        'size': 'large',
        'coat_type': 'Short',
        'medical_notes': 'None',
        'behaviour_notes': 'Friendly',
        'care_notes': 'Needs walks',
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-02T10:00:00Z',
      });

      expect(pet.id, 'pet-1');
      expect(pet.ownerId, 'owner-1');
      expect(pet.name, 'Buddy');
      expect(pet.species, 'Dog');
      expect(pet.breed, 'Labrador');
      expect(pet.ageYears, 3.5);
      expect(pet.size, 'large');
      expect(pet.coatType, 'Short');
      expect(pet.medicalNotes, 'None');
      expect(pet.behaviourNotes, 'Friendly');
      expect(pet.careNotes, 'Needs walks');
    });

    test('keeps nullable fields null', () {
      final pet = PetModel.fromMap({
        'id': 'pet-2',
        'owner_id': 'owner-1',
        'name': 'Mochi',
        'species': 'Cat',
        'breed': null,
        'age_years': null,
        'size': null,
        'coat_type': null,
        'medical_notes': null,
        'behaviour_notes': null,
        'care_notes': null,
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-01T10:00:00Z',
      });

      expect(pet.breed, isNull);
      expect(pet.ageYears, isNull);
      expect(pet.size, isNull);
      expect(pet.coatType, isNull);
      expect(pet.medicalNotes, isNull);
      expect(pet.behaviourNotes, isNull);
      expect(pet.careNotes, isNull);
    });
  });

  group('PetRepository validation', () {
    test('converts blank optional text to null', () {
      final payload = PetRepository.validatePetFields(
        name: '  Buddy  ',
        species: '  Dog  ',
        breed: '   ',
        coatType: '',
        medicalNotes: '  ',
        behaviourNotes: null,
        careNotes: ' needs walks ',
      );

      expect(payload['name'], 'Buddy');
      expect(payload['species'], 'Dog');
      expect(payload['breed'], isNull);
      expect(payload['coat_type'], isNull);
      expect(payload['medical_notes'], isNull);
      expect(payload['behaviour_notes'], isNull);
      expect(payload['care_notes'], 'needs walks');
    });

    test('rejects invalid age', () {
      expect(
        () => PetRepository.validatePetFields(
          name: 'Buddy',
          species: 'Dog',
          ageYears: 101,
        ),
        throwsA(
          isA<PetException>().having(
            (e) => e.message,
            'message',
            contains('Age'),
          ),
        ),
      );
    });

    test('rejects invalid size', () {
      expect(
        () => PetRepository.validatePetFields(
          name: 'Buddy',
          species: 'Dog',
          size: 'huge',
        ),
        throwsA(
          isA<PetException>().having(
            (e) => e.message,
            'message',
            contains('Size'),
          ),
        ),
      );
    });

    test('rejects short name', () {
      expect(
        () => PetRepository.validatePetFields(name: 'A', species: 'Dog'),
        throwsA(
          isA<PetException>().having(
            (e) => e.message,
            'message',
            contains('Name'),
          ),
        ),
      );
    });

    test('rejects long breed', () {
      expect(
        () => PetRepository.validatePetFields(
          name: 'Buddy',
          species: 'Dog',
          breed: 'x' * 81,
        ),
        throwsA(
          isA<PetException>().having(
            (e) => e.message,
            'message',
            contains('Breed'),
          ),
        ),
      );
    });
  });
}
