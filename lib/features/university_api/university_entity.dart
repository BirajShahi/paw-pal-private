import 'dart:convert';

/// One record from the university dashboard `entities` list.
///
/// Fields are kept as a map because each class location returns different
/// property names. The detail screen prints every entry in this map.
class UniversityEntity {
  UniversityEntity(Map<String, dynamic> properties)
    : properties = Map<String, dynamic>.unmodifiable(properties);

  final Map<String, dynamic> properties;

  /// The description field, when the API included one.
  String? get description {
    final value = properties['description'];
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  /// Short label for a [ListView] row. Skips the long description.
  String listTitle(int index) {
    for (final entry in properties.entries) {
      if (entry.key.toLowerCase() == 'description') continue;
      final value = entry.value;
      if (value is! String) continue;
      final text = value.trim();
      if (text.isEmpty || text.length > 80) continue;
      return text;
    }
    return 'Entity ${index + 1}';
  }
}

/// Turns `scientificName` or `common_name` into a readable label.
String universityPropertyLabel(String key) {
  final spaced = key.replaceAll('_', ' ').replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) {
      return '${match.group(1)} ${match.group(2)}';
    },
  );
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Turns any JSON value into text that can be shown on screen.
String universityPropertyValue(Object? value) {
  if (value == null) return '—';
  if (value is Map || value is List) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }
  final text = value.toString().trim();
  return text.isEmpty ? '—' : text;
}
