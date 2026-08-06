import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_model.dart';

/// Thrown when a profile cannot be loaded or an update is invalid.
class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Supabase access for `public.profiles`.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<ProfileModel> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProfileException(
        'You are not signed in. Please log in again.',
      );
    }

    final row = await _client
        .from('profiles')
        .select(
          'id, role, full_name, suburb, postcode, service_description, '
          'hourly_price, latitude, longitude',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      throw const ProfileException(
        'Your profile could not be found. Please contact support.',
      );
    }

    try {
      return ProfileModel.fromMap(row);
    } on FormatException catch (error) {
      throw ProfileException(error.message);
    }
  }

  Future<ProfileModel> updateOwnerProfile({
    required String fullName,
    String? suburb,
    String? postcode,
  }) async {
    final userId = _requireUserId();
    final payload = <String, dynamic>{
      'full_name': fullName.trim(),
      'suburb': _trimOrNull(suburb),
      'postcode': _trimOrNull(postcode),
    };

    return _updateAndReturn(userId, payload);
  }

  Future<ProfileModel> updateSitterProfile({
    required String fullName,
    String? suburb,
    String? postcode,
    String? serviceDescription,
    double? hourlyPrice,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _requireUserId();
    _validateSitterFields(
      hourlyPrice: hourlyPrice,
      latitude: latitude,
      longitude: longitude,
    );

    final payload = <String, dynamic>{
      'full_name': fullName.trim(),
      'suburb': _trimOrNull(suburb),
      'postcode': _trimOrNull(postcode),
      'service_description': _trimOrNull(serviceDescription),
      'hourly_price': hourlyPrice,
      'latitude': latitude,
      'longitude': longitude,
    };

    return _updateAndReturn(userId, payload);
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProfileException(
        'You are not signed in. Please log in again.',
      );
    }
    return user.id;
  }

  Future<ProfileModel> _updateAndReturn(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    if ((payload['full_name'] as String).isEmpty) {
      throw const ProfileException('Full name is required.');
    }

    final row = await _client
        .from('profiles')
        .update(payload)
        .eq('id', userId)
        .select(
          'id, role, full_name, suburb, postcode, service_description, '
          'hourly_price, latitude, longitude',
        )
        .maybeSingle();

    if (row == null) {
      throw const ProfileException(
        'Your profile could not be updated. Please try again.',
      );
    }

    try {
      return ProfileModel.fromMap(row);
    } on FormatException catch (error) {
      throw ProfileException(error.message);
    }
  }

  static void validateSitterCoordinatesAndPrice({
    double? hourlyPrice,
    double? latitude,
    double? longitude,
  }) {
    _validateSitterFields(
      hourlyPrice: hourlyPrice,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static void _validateSitterFields({
    double? hourlyPrice,
    double? latitude,
    double? longitude,
  }) {
    if (hourlyPrice != null && hourlyPrice < 0) {
      throw const ProfileException('Hourly price cannot be negative.');
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw const ProfileException('Latitude must be between -90 and 90.');
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw const ProfileException('Longitude must be between -180 and 180.');
    }
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
