import '../auth/auth_role.dart';

/// Row from `public.profiles`.
class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.role,
    required this.fullName,
    this.suburb,
    this.postcode,
    this.serviceDescription,
    this.hourlyPrice,
    this.latitude,
    this.longitude,
  });

  final String id;
  final AuthRole role;
  final String fullName;
  final String? suburb;
  final String? postcode;
  final String? serviceDescription;
  final double? hourlyPrice;
  final double? latitude;
  final double? longitude;

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    final role = AuthRole.tryParse(map['role'] as String?);
    if (role == null) {
      throw const FormatException('Profile role is missing or unsupported.');
    }

    final id = map['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('Profile id is missing.');
    }

    final fullName = map['full_name'] as String?;
    if (fullName == null || fullName.trim().isEmpty) {
      throw const FormatException('Profile full name is missing.');
    }

    return ProfileModel(
      id: id,
      role: role,
      fullName: fullName,
      suburb: map['suburb'] as String?,
      postcode: map['postcode'] as String?,
      serviceDescription: map['service_description'] as String?,
      hourlyPrice: _toDouble(map['hourly_price']),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
    );
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
