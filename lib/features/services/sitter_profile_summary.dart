/// Minimal public sitter profile fields for exact service matching.
class SitterProfileSummary {
  SitterProfileSummary({
    required String id,
    required String fullName,
    String? suburb,
    String? postcode,
    String? serviceDescription,
    double? latitude,
    double? longitude,
  }) : id = id.trim(),
       fullName = fullName.trim(),
       suburb = _trimOrNull(suburb),
       postcode = _trimOrNull(postcode),
       serviceDescription = _trimOrNull(serviceDescription),
       latitude = _validatedLatitude(latitude),
       longitude = _validatedLongitude(longitude) {
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
  final double? latitude;
  final double? longitude;

  factory SitterProfileSummary.fromMap(Map<String, dynamic> map) {
    return SitterProfileSummary(
      id: (map['id'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? '',
      suburb: map['suburb'] as String?,
      postcode: map['postcode'] as String?,
      serviceDescription: map['service_description'] as String?,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
    );
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static double? _validatedLatitude(double? value) {
    if (value == null) return null;
    if (value < -90 || value > 90) {
      throw const FormatException('Latitude must be between -90 and 90.');
    }
    return value;
  }

  static double? _validatedLongitude(double? value) {
    if (value == null) return null;
    if (value < -180 || value > 180) {
      throw const FormatException('Longitude must be between -180 and 180.');
    }
    return value;
  }
}
