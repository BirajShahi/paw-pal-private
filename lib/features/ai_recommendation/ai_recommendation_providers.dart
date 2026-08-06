import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_recommendation_repository.dart';

final aiRecommendationRepositoryProvider = Provider<AiRecommendationRepository>(
  (ref) {
    return AiRecommendationRepository(Supabase.instance.client);
  },
);
