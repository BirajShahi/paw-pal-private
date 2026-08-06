import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_role.dart';

/// Thrown when the signed-in user's profile or role cannot be resolved.
class ProfileRoleException implements Exception {
  const ProfileRoleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin Supabase authentication wrapper.
///
/// [AuthException] from Supabase is left uncaught for the UI to handle.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  /// Auth state changes with a safe error handler so stream errors do not
  /// become unhandled zone exceptions (required by gotrue).
  Stream<AuthState> get authStateChanges {
    return Stream.multi((controller) {
      final subscription = _client.auth.onAuthStateChange.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
    required AuthRole role,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'role': role.value},
    );
  }

  Future<AuthResponse> logIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logOut() {
    return _client.auth.signOut();
  }

  /// Reads the signed-in user's role from `public.profiles`.
  ///
  /// Only `owner` and `sitter` are accepted.
  Future<AuthRole> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) {
      throw const ProfileRoleException(
        'You are not signed in. Please log in again.',
      );
    }

    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      throw const ProfileRoleException(
        'Your profile could not be found. Please contact support.',
      );
    }

    final role = AuthRole.tryParse(row['role'] as String?);
    if (role == null) {
      throw const ProfileRoleException(
        'Your account role is missing or unsupported. Please contact support.',
      );
    }

    return role;
  }
}
