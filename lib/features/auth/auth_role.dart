/// Allowed PawPal authentication roles.
enum AuthRole {
  owner,
  sitter;

  /// Wire value stored in Supabase user metadata / profiles.
  String get value => name;

  /// Parses a stored role string. Returns null when missing or unsupported.
  static AuthRole? tryParse(String? value) {
    return switch (value) {
      'owner' => AuthRole.owner,
      'sitter' => AuthRole.sitter,
      _ => null,
    };
  }
}
