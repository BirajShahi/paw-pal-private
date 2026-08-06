import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_recommendation_preparation_result.dart';
import 'ai_recommendation_request.dart';

/// Thrown when recommendation preparation fails.
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

  Future<AiRecommendationPreparationResult> prepareRecommendation(
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
          'Could not prepare your recommendation. Please try again.',
        );
      }

      return AiRecommendationPreparationResult.fromMap(
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
        'Could not prepare your recommendation. Please try again.',
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
      503 => 'Service catalogue is temporarily unavailable.',
      _ => 'Could not prepare your recommendation. Please try again.',
    };
  }
}
