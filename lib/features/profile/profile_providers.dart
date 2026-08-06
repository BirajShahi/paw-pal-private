import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

/// Current signed-in user's profile. Refresh with `ref.invalidate`.
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return null;
  }

  return ref.read(profileRepositoryProvider).getCurrentProfile();
});
