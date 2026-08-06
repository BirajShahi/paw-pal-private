/// Success payload from the recommend-service Edge Function (T09B1).
class AiRecommendationPreparationResult {
  AiRecommendationPreparationResult({
    required this.ready,
    required this.petId,
    required this.serviceCount,
    required this.requestId,
  });

  final bool ready;
  final String petId;
  final int serviceCount;
  final String requestId;

  factory AiRecommendationPreparationResult.fromMap(Map<String, dynamic> map) {
    if (map['ready'] != true) {
      throw const FormatException('Preparation result is not ready.');
    }

    final petId = (map['petId'] as String?)?.trim() ?? '';
    final requestId = (map['requestId'] as String?)?.trim() ?? '';
    if (petId.isEmpty || requestId.isEmpty) {
      throw const FormatException('Preparation result is incomplete.');
    }

    final rawCount = map['serviceCount'];
    final serviceCount = switch (rawCount) {
      int value => value,
      num value => value.toInt(),
      _ => null,
    };
    if (serviceCount == null || serviceCount < 1) {
      throw const FormatException('Preparation result has no services.');
    }

    return AiRecommendationPreparationResult(
      ready: true,
      petId: petId,
      serviceCount: serviceCount,
      requestId: requestId,
    );
  }
}
