import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'sitter_service_model.dart';
import 'sitter_service_repository.dart';

final sitterServiceRepositoryProvider = Provider<SitterServiceRepository>((
  ref,
) {
  return SitterServiceRepository(Supabase.instance.client);
});

/// Offerings owned by the signed-in sitter. Refresh with `ref.invalidate`.
final currentSitterServicesProvider = FutureProvider<List<SitterServiceModel>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const SitterServiceException(
      'You are not signed in. Please log in again.',
    );
  }

  return ref.read(sitterServiceRepositoryProvider).getCurrentSitterServices();
});

/// Active offerings for a catalogue service. Refresh with `ref.invalidate`.
final activeOfferingsForServiceProvider =
    FutureProvider.family<List<SitterServiceModel>, String>((
      ref,
      serviceId,
    ) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        throw const SitterServiceException(
          'You are not signed in. Please log in again.',
        );
      }

      return ref
          .read(sitterServiceRepositoryProvider)
          .getActiveOfferingsForService(serviceId);
    });

/// One offering owned by the signed-in sitter. Refresh with `ref.invalidate`.
final sitterServiceByIdProvider =
    FutureProvider.family<SitterServiceModel, String>((ref, offeringId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        throw const SitterServiceException(
          'You are not signed in. Please log in again.',
        );
      }

      return ref
          .read(sitterServiceRepositoryProvider)
          .getSitterServiceById(offeringId);
    });
