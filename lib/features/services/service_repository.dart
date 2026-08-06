import 'package:supabase_flutter/supabase_flutter.dart';

import 'service_model.dart';

/// Thrown when a service cannot be loaded.
class ServiceException implements Exception {
  const ServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _serviceSelect =
    'id, code, name, category, description, included_items, '
    'recommendation_tags, can_be_add_on, is_active, display_order, '
    'created_at, updated_at';

/// Read-only Supabase access for `public.services`.
class ServiceRepository {
  ServiceRepository(this._client);

  final SupabaseClient _client;

  Future<List<ServiceModel>> getActiveServices() async {
    _requireUserId();

    final rows = await _client
        .from('services')
        .select(_serviceSelect)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return [
      for (final row in rows as List<dynamic>)
        ServiceModel.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<ServiceModel> getServiceByCode(String code) async {
    _requireUserId();

    final normalised = code.trim().toLowerCase();
    if (normalised.isEmpty) {
      throw const ServiceException('Service code is required.');
    }

    final row = await _client
        .from('services')
        .select(_serviceSelect)
        .eq('code', normalised)
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) {
      throw const ServiceException('That service is unavailable.');
    }

    try {
      return ServiceModel.fromMap(row);
    } on FormatException catch (error) {
      throw ServiceException(error.message);
    }
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ServiceException(
        'You are not signed in. Please log in again.',
      );
    }
    return user.id;
  }
}
