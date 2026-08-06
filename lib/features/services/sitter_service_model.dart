import 'service_model.dart';
import 'sitter_profile_summary.dart';

/// Row from `public.sitter_services`, optionally with joined catalogue service
/// and sitter profile.
class SitterServiceModel {
  const SitterServiceModel({
    required this.id,
    required this.sitterId,
    required this.serviceId,
    required this.price,
    this.estimatedDurationMinutes,
    this.serviceNotes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.service,
    this.sitter,
  });

  final String id;
  final String sitterId;
  final String serviceId;
  final double price;
  final int? estimatedDurationMinutes;
  final String? serviceNotes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ServiceModel? service;
  final SitterProfileSummary? sitter;

  factory SitterServiceModel.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] as String?)?.trim() ?? '';
    final sitterId = (map['sitter_id'] as String?)?.trim() ?? '';
    final serviceId = (map['service_id'] as String?)?.trim() ?? '';
    final price = _toDouble(map['price']);
    final duration = _toInt(map['estimated_duration_minutes']);
    final notes = _trimOrNull(map['service_notes'] as String?);
    final createdAt = _parseDateTime(map['created_at']);
    final updatedAt = _parseDateTime(map['updated_at']);

    if (id.isEmpty) {
      throw const FormatException('Sitter service id is missing.');
    }
    if (sitterId.isEmpty) {
      throw const FormatException('Sitter id is missing.');
    }
    if (serviceId.isEmpty) {
      throw const FormatException('Service id is missing.');
    }
    if (price == null) {
      throw const FormatException('Price is missing.');
    }
    if (price <= 0 || price > 1000) {
      throw const FormatException(
        'Price must be greater than 0 and at most 1000.',
      );
    }
    if (duration != null && (duration < 15 || duration > 1440)) {
      throw const FormatException(
        'Estimated duration must be between 15 and 1440 minutes.',
      );
    }
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('Sitter service timestamps are missing.');
    }

    ServiceModel? service;
    final nestedService = map['services'];
    if (nestedService is Map<String, dynamic>) {
      service = ServiceModel.fromMap(nestedService);
    } else if (nestedService is Map) {
      service = ServiceModel.fromMap(Map<String, dynamic>.from(nestedService));
    }

    SitterProfileSummary? sitter;
    final nestedSitter = map['profiles'] ?? map['sitter'];
    if (nestedSitter is Map<String, dynamic>) {
      sitter = SitterProfileSummary.fromMap(nestedSitter);
    } else if (nestedSitter is Map) {
      sitter = SitterProfileSummary.fromMap(
        Map<String, dynamic>.from(nestedSitter),
      );
    }

    return SitterServiceModel(
      id: id,
      sitterId: sitterId,
      serviceId: serviceId,
      price: price,
      estimatedDurationMinutes: duration,
      serviceNotes: notes,
      isActive: map['is_active'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      service: service,
      sitter: sitter,
    );
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
