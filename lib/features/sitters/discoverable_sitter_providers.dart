import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../services/sitter_service_providers.dart';
import '../services/sitter_service_repository.dart';
import 'discoverable_sitter.dart';

/// Active providers grouped for owner discovery. Refresh with `ref.invalidate`.
final discoverableSittersProvider = FutureProvider<List<DiscoverableSitter>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const SitterServiceException(
      'You are not signed in. Please log in again.',
    );
  }

  final offerings = await ref
      .read(sitterServiceRepositoryProvider)
      .getAllActiveSitterOfferings();

  return groupOfferingsIntoDiscoverableSitters(offerings);
});
