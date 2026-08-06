/// Row from `public.pets`.
class PetModel {
  const PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    this.breed,
    this.ageYears,
    this.size,
    this.coatType,
    this.medicalNotes,
    this.behaviourNotes,
    this.careNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String species;
  final String? breed;
  final double? ageYears;
  final String? size;
  final String? coatType;
  final String? medicalNotes;
  final String? behaviourNotes;
  final String? careNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PetModel.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final ownerId = map['owner_id'] as String?;
    final name = map['name'] as String?;
    final species = map['species'] as String?;
    final createdAt = _parseDateTime(map['created_at']);
    final updatedAt = _parseDateTime(map['updated_at']);

    if (id == null || id.isEmpty) {
      throw const FormatException('Pet id is missing.');
    }
    if (ownerId == null || ownerId.isEmpty) {
      throw const FormatException('Pet owner id is missing.');
    }
    if (name == null || name.trim().isEmpty) {
      throw const FormatException('Pet name is missing.');
    }
    if (species == null || species.trim().isEmpty) {
      throw const FormatException('Pet species is missing.');
    }
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('Pet timestamps are missing.');
    }

    return PetModel(
      id: id,
      ownerId: ownerId,
      name: name,
      species: species,
      breed: map['breed'] as String?,
      ageYears: _toDouble(map['age_years']),
      size: map['size'] as String?,
      coatType: map['coat_type'] as String?,
      medicalNotes: map['medical_notes'] as String?,
      behaviourNotes: map['behaviour_notes'] as String?,
      careNotes: map['care_notes'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
