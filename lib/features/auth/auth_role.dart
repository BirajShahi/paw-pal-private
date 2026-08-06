/// Allowed PawPal authentication roles.
enum AuthRole {
  owner,
  sitter;

  /// Wire value stored in Supabase user metadata.
  String get value => name;
}
