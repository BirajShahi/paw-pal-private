import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'service_providers.dart';
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

/// Active sitter matches for a controlled service code.
/// Refresh with `ref.invalidate`.
final activeSitterMatchesByServiceCodeProvider =
    FutureProvider.family<List<SitterServiceModel>, String>((ref, code) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        throw const SitterServiceException(
          'You are not signed in. Please log in again.',
        );
      }

      final normalised = normalizeMatchServiceCode(code);
      final service = await ref.watch(serviceByCodeProvider(normalised).future);

      final offerings = await ref
          .read(sitterServiceRepositoryProvider)
          .getActiveOfferingsForService(service.id);

      return [
        for (final offering in offerings)
          if (offering.isActive &&
              offering.sitter != null &&
              offering.serviceId == service.id)
            offering,
      ];
    });

/// Trims and lowercases a controlled service code for exact matching.
String normalizeMatchServiceCode(String code) {
  final normalised = code.trim().toLowerCase();
  if (normalised.isEmpty) {
    throw const SitterServiceException('Service code is required.');
  }
  return normalised;
}

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
