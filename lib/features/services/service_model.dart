import 'service_category.dart';

/// Row from `public.services`.
class ServiceModel {
  ServiceModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.description,
    required List<String> includedItems,
    required List<String> recommendationTags,
    required this.canBeAddOn,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  }) : includedItems = List.unmodifiable(includedItems),
       recommendationTags = List.unmodifiable(recommendationTags);

  final String id;
  final String code;
  final String name;
  final ServiceCategory category;
  final String description;
  final List<String> includedItems;
  final List<String> recommendationTags;
  final bool canBeAddOn;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] as String?)?.trim() ?? '';
    final code = (map['code'] as String?)?.trim() ?? '';
    final name = (map['name'] as String?)?.trim() ?? '';
    final description = (map['description'] as String?)?.trim() ?? '';
    final categoryRaw = map['category'] as String?;
    final displayOrder = _toInt(map['display_order']);
    final createdAt = _parseDateTime(map['created_at']);
    final updatedAt = _parseDateTime(map['updated_at']);

    if (id.isEmpty) {
      throw const FormatException('Service id is missing.');
    }
    if (code.isEmpty) {
      throw const FormatException('Service code is missing.');
    }
    if (name.isEmpty) {
      throw const FormatException('Service name is missing.');
    }
    if (description.isEmpty) {
      throw const FormatException('Service description is missing.');
    }
    if (categoryRaw == null) {
      throw const FormatException('Service category is missing.');
    }
    if (displayOrder == null) {
      throw const FormatException('Service display order is missing.');
    }
    if (displayOrder < 0) {
      throw const FormatException('Service display order cannot be negative.');
    }
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('Service timestamps are missing.');
    }

    final category = ServiceCategory.fromDatabaseValue(categoryRaw);

    return ServiceModel(
      id: id,
      code: code,
      name: name,
      category: category,
      description: description,
      includedItems: _toStringList(map['included_items']),
      recommendationTags: _toStringList(map['recommendation_tags']),
      canBeAddOn: map['can_be_add_on'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? false,
      displayOrder: displayOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static List<String> _toStringList(Object? value) {
    if (value == null) return const [];
    if (value is List) {
      return [
        for (final item in value)
          if (item != null) item.toString(),
      ];
    }
    return const [];
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
}
