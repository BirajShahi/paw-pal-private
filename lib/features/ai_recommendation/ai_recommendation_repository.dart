import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_recommendation_request.dart';
import 'ai_service_recommendation_result.dart';

/// Thrown when recommendation generation fails.
class AiRecommendationException implements Exception {
  const AiRecommendationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Invokes the authenticated recommend-service Edge Function.
class AiRecommendationRepository {
  AiRecommendationRepository(this._client);

  final SupabaseClient _client;

  Future<AiServiceRecommendationResult> recommendService(
    AiRecommendationRequest request,
  ) async {
    if (_client.auth.currentSession == null) {
      throw const AiRecommendationException(
        'You are not signed in. Please log in again.',
      );
    }

    try {
      final response = await _client.functions.invoke(
        'recommend-service',
        body: request.toMap(),
      );

      final data = response.data;
      if (data is! Map) {
        throw const AiRecommendationException(
          'PawPal could not generate a recommendation right now. Please try again.',
        );
      }

      return AiServiceRecommendationResult.fromMap(
        Map<String, dynamic>.from(data),
      );
    } on AiRecommendationException {
      rethrow;
    } on FunctionException catch (error) {
      throw AiRecommendationException(_messageFromFunctionException(error));
    } on FormatException catch (error) {
      throw AiRecommendationException(error.message);
    } catch (_) {
      throw const AiRecommendationException(
        'PawPal could not generate a recommendation right now. Please try again.',
      );
    }
  }

  static String _messageFromFunctionException(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final nested = details['error'];
      if (nested is Map) {
        final message = nested['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      final message = details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return switch (error.status) {
      403 => 'Only pet owners can request service recommendations.',
      404 => 'Pet not found.',
      429 =>
        'PawPal could not generate a recommendation right now. Please try again.',
      503 =>
        'PawPal could not generate a recommendation right now. Please try again.',
      _ =>
        'PawPal could not generate a recommendation right now. Please try again.',
    };
  }
}
