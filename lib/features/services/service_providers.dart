import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'service_model.dart';
import 'service_repository.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository(Supabase.instance.client);
});

/// Active catalogue services. Refresh with `ref.invalidate`.
final activeServicesProvider = FutureProvider<List<ServiceModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const ServiceException('You are not signed in. Please log in again.');
  }

  return ref.read(serviceRepositoryProvider).getActiveServices();
});

/// One active service by stable code. Refresh with `ref.invalidate`.
final serviceByCodeProvider = FutureProvider.family<ServiceModel, String>((
  ref,
  code,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw const ServiceException('You are not signed in. Please log in again.');
  }

  return ref.read(serviceRepositoryProvider).getServiceByCode(code);
});
