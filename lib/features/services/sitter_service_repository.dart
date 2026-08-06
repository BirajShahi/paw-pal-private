import 'package:supabase_flutter/supabase_flutter.dart';

import 'sitter_service_model.dart';

/// Thrown when a sitter service offering cannot be loaded or saved.
class SitterServiceException implements Exception {
  const SitterServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _sitterServiceSelect =
    'id, sitter_id, service_id, price, estimated_duration_minutes, '
    'service_notes, is_active, created_at, updated_at, '
    'services ( id, code, name, category, description, included_items, '
    'recommendation_tags, can_be_add_on, is_active, display_order, '
    'created_at, updated_at )';

const _activeOfferingsSelect =
    'id, sitter_id, service_id, price, estimated_duration_minutes, '
    'service_notes, is_active, created_at, updated_at, '
    'services ( id, code, name, category, description, included_items, '
    'recommendation_tags, can_be_add_on, is_active, display_order, '
    'created_at, updated_at ), '
    'profiles ( id, full_name, suburb, postcode, service_description )';

/// Supabase access for `public.sitter_services`.
class SitterServiceRepository {
  SitterServiceRepository(this._client);

  final SupabaseClient _client;

  Future<List<SitterServiceModel>> getCurrentSitterServices() async {
    final userId = _requireUserId();

    final rows = await _client
        .from('sitter_services')
        .select(_sitterServiceSelect)
        .eq('sitter_id', userId)
        .order('display_order', ascending: true, referencedTable: 'services');

    return [
      for (final row in rows as List<dynamic>)
        SitterServiceModel.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<SitterServiceModel>> getActiveOfferingsForService(
    String serviceId,
  ) async {
    _requireUserId();

    final trimmedId = serviceId.trim();
    if (trimmedId.isEmpty) {
      throw const SitterServiceException('Service id is required.');
    }

    final rows = await _client
        .from('sitter_services')
        .select(_activeOfferingsSelect)
        .eq('service_id', trimmedId)
        .eq('is_active', true)
        .order('price', ascending: true)
        .order('created_at', ascending: true);

    final offerings = <SitterServiceModel>[];
    for (final row in rows as List<dynamic>) {
      try {
        final offering = SitterServiceModel.fromMap(
          Map<String, dynamic>.from(row as Map),
        );
        if (offering.sitter == null) {
          continue;
        }
        offerings.add(offering);
      } on FormatException {
        // Skip malformed rows that cannot form a valid match listing.
      }
    }
    return offerings;
  }

  Future<SitterServiceModel> getSitterServiceById(String offeringId) async {
    final userId = _requireUserId();
    final trimmedId = offeringId.trim();
    if (trimmedId.isEmpty) {
      throw const SitterServiceException('Offering id is required.');
    }

    final row = await _client
        .from('sitter_services')
        .select(_sitterServiceSelect)
        .eq('id', trimmedId)
        .eq('sitter_id', userId)
        .maybeSingle();

    if (row == null) {
      throw const SitterServiceException('Service offering not found.');
    }

    try {
      return SitterServiceModel.fromMap(row);
    } on FormatException catch (error) {
      throw SitterServiceException(error.message);
    }
  }

  Future<SitterServiceModel> createSitterService({
    required String serviceId,
    required double price,
    int? estimatedDurationMinutes,
    String? serviceNotes,
  }) async {
    final userId = _requireUserId();
    final payload = _validatedPayload(
      serviceId: serviceId,
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
      serviceNotes: serviceNotes,
    );

    final row = await _client
        .from('sitter_services')
        .insert({...payload, 'sitter_id': userId, 'is_active': true})
        .select(_sitterServiceSelect)
        .single();

    try {
      return SitterServiceModel.fromMap(row);
    } on FormatException catch (error) {
      throw SitterServiceException(error.message);
    }
  }

  Future<SitterServiceModel> updateSitterService({
    required String offeringId,
    required double price,
    int? estimatedDurationMinutes,
    String? serviceNotes,
    required bool isActive,
  }) async {
    final userId = _requireUserId();
    final trimmedOfferingId = offeringId.trim();
    if (trimmedOfferingId.isEmpty) {
      throw const SitterServiceException('Offering id is required.');
    }

    _validatePriceAndDuration(
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
    );
    final notes = _trimNotes(serviceNotes);

    final row = await _client
        .from('sitter_services')
        .update({
          'price': price,
          'estimated_duration_minutes': estimatedDurationMinutes,
          'service_notes': notes,
          'is_active': isActive,
        })
        .eq('id', trimmedOfferingId)
        .eq('sitter_id', userId)
        .select(_sitterServiceSelect)
        .maybeSingle();

    if (row == null) {
      throw const SitterServiceException('Service offering not found.');
    }

    try {
      return SitterServiceModel.fromMap(row);
    } on FormatException catch (error) {
      throw SitterServiceException(error.message);
    }
  }

  Future<void> deleteSitterService(String offeringId) async {
    final userId = _requireUserId();
    final trimmedOfferingId = offeringId.trim();
    if (trimmedOfferingId.isEmpty) {
      throw const SitterServiceException('Offering id is required.');
    }

    await _client
        .from('sitter_services')
        .delete()
        .eq('id', trimmedOfferingId)
        .eq('sitter_id', userId);
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SitterServiceException(
        'You are not signed in. Please log in again.',
      );
    }
    return user.id;
  }

  /// Exposed for unit tests without a live Supabase client.
  static Map<String, dynamic> validateSitterServiceFields({
    required String serviceId,
    required double price,
    int? estimatedDurationMinutes,
    String? serviceNotes,
  }) {
    return _validatedPayload(
      serviceId: serviceId,
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
      serviceNotes: serviceNotes,
    );
  }

  static Map<String, dynamic> _validatedPayload({
    required String serviceId,
    required double price,
    int? estimatedDurationMinutes,
    String? serviceNotes,
  }) {
    final trimmedServiceId = serviceId.trim();
    if (trimmedServiceId.isEmpty) {
      throw const SitterServiceException('Service id is required.');
    }

    _validatePriceAndDuration(
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
    );

    return {
      'service_id': trimmedServiceId,
      'price': price,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'service_notes': _trimNotes(serviceNotes),
    };
  }

  static void _validatePriceAndDuration({
    required double price,
    int? estimatedDurationMinutes,
  }) {
    if (price <= 0 || price > 1000) {
      throw const SitterServiceException(
        'Price must be greater than 0 and at most 1000.',
      );
    }
    if (estimatedDurationMinutes != null &&
        (estimatedDurationMinutes < 15 || estimatedDurationMinutes > 1440)) {
      throw const SitterServiceException(
        'Estimated duration must be between 15 and 1440 minutes.',
      );
    }
  }

  static String? _trimNotes(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 500) {
      throw const SitterServiceException(
        'Service notes may contain up to 500 characters.',
      );
    }
    return trimmed;
  }
}
