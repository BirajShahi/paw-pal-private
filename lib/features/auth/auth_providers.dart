import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'auth_role.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});

/// Loads the signed-in user's role from `public.profiles`.
///
/// Returns `null` when signed out. Re-runs when the authenticated user changes.
final currentUserRoleProvider = FutureProvider<AuthRole?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return null;
  }

  return ref.read(authRepositoryProvider).getCurrentUserRole();
});
