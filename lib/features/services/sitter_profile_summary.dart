/// Minimal public sitter profile fields for exact service matching.
class SitterProfileSummary {
  SitterProfileSummary({
    required String id,
    required String fullName,
    String? suburb,
    String? postcode,
    String? serviceDescription,
  }) : id = id.trim(),
       fullName = fullName.trim(),
       suburb = _trimOrNull(suburb),
       postcode = _trimOrNull(postcode),
       serviceDescription = _trimOrNull(serviceDescription) {
    if (this.id.isEmpty) {
      throw const FormatException('Sitter id is missing.');
    }
    if (this.fullName.isEmpty) {
      throw const FormatException('Sitter full name is missing.');
    }
  }

  final String id;
  final String fullName;
  final String? suburb;
  final String? postcode;
  final String? serviceDescription;

  factory SitterProfileSummary.fromMap(Map<String, dynamic> map) {
    return SitterProfileSummary(
      id: (map['id'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? '',
      suburb: map['suburb'] as String?,
      postcode: map['postcode'] as String?,
      serviceDescription: map['service_description'] as String?,
    );
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
