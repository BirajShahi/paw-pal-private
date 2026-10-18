import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'university_api_client.dart';

/// The university API client used by the login screen.
///
/// This is PawPal's Flutter dependency injection for the NIT3213 API.
/// Tests can pass a fake client into the screen, or override this provider.
final universityApiClientProvider = Provider<UniversityApiClient>((ref) {
  return UniversityApiClient();
});
