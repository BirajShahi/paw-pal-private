/// Controlled service categories from `public.services`.
enum ServiceCategory {
  grooming,
  walking,
  homeCare,
  sitting;

  String get databaseValue => switch (this) {
    ServiceCategory.grooming => 'grooming',
    ServiceCategory.walking => 'walking',
    ServiceCategory.homeCare => 'home_care',
    ServiceCategory.sitting => 'sitting',
  };

  String get displayName => switch (this) {
    ServiceCategory.grooming => 'Grooming',
    ServiceCategory.walking => 'Dog Walking',
    ServiceCategory.homeCare => 'Home Care',
    ServiceCategory.sitting => 'Pet Sitting',
  };

  static ServiceCategory fromDatabaseValue(String value) {
    return switch (value) {
      'grooming' => ServiceCategory.grooming,
      'walking' => ServiceCategory.walking,
      'home_care' => ServiceCategory.homeCare,
      'sitting' => ServiceCategory.sitting,
      _ => throw FormatException('Unsupported service category: $value'),
    };
  }
}
