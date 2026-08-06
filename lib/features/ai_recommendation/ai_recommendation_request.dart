/// In-memory request for a future AI service recommendation.
class AiRecommendationRequest {
  AiRecommendationRequest({
    required String petId,
    required String ownerDescription,
  }) : petId = petId.trim(),
       ownerDescription = ownerDescription.trim() {
    if (this.petId.isEmpty) {
      throw const FormatException('Pet id is required.');
    }
    if (this.ownerDescription.length < 20 ||
        this.ownerDescription.length > 1000) {
      throw const FormatException(
        'Description must be between 20 and 1000 characters.',
      );
    }
  }

  final String petId;
  final String ownerDescription;
}

String? validateAiRecommendationDescription(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Please describe what your pet needs today';
  }
  if (trimmed.length < 20) {
    return 'Please enter at least 20 characters';
  }
  if (trimmed.length > 1000) {
    return 'Description may contain up to 1000 characters';
  }
  return null;
}
