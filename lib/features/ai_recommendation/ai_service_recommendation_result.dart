/// Outcomes returned by the recommend-service Edge Function.
enum AiRecommendationOutcome { serviceRecommendation, urgentVet }

extension AiRecommendationOutcomeMapping on AiRecommendationOutcome {
  static AiRecommendationOutcome fromApi(String value) {
    return switch (value) {
      'service_recommendation' => AiRecommendationOutcome.serviceRecommendation,
      'urgent_vet' => AiRecommendationOutcome.urgentVet,
      _ => throw const FormatException('Unknown recommendation outcome.'),
    };
  }

  String get apiValue => switch (this) {
    AiRecommendationOutcome.serviceRecommendation => 'service_recommendation',
    AiRecommendationOutcome.urgentVet => 'urgent_vet',
  };
}

/// Catalogue service summary shown to owners (names from the database).
class RecommendedServiceSummary {
  RecommendedServiceSummary({required String code, required String name})
    : code = code.trim(),
      name = name.trim() {
    if (this.code.isEmpty || this.name.isEmpty) {
      throw const FormatException('Service summary is incomplete.');
    }
  }

  final String code;
  final String name;

  factory RecommendedServiceSummary.fromMap(Map<String, dynamic> map) {
    final code = (map['code'] as String?) ?? '';
    final name = (map['name'] as String?) ?? '';
    return RecommendedServiceSummary(code: code, name: name);
  }
}

/// Structured AI recommendation returned by recommend-service.
class AiServiceRecommendationResult {
  AiServiceRecommendationResult({
    required this.requestId,
    required this.outcome,
    required this.primaryService,
    required List<RecommendedServiceSummary> additionalServices,
    required this.reasoning,
    required List<String> sitterRequirements,
    required this.ownerAdvice,
    required this.safetyNotice,
  }) : additionalServices = List<RecommendedServiceSummary>.unmodifiable(
         additionalServices,
       ),
       sitterRequirements = List<String>.unmodifiable(sitterRequirements);

  final String requestId;
  final AiRecommendationOutcome outcome;
  final RecommendedServiceSummary? primaryService;
  final List<RecommendedServiceSummary> additionalServices;
  final String reasoning;
  final List<String> sitterRequirements;
  final String ownerAdvice;
  final String safetyNotice;

  factory AiServiceRecommendationResult.fromMap(Map<String, dynamic> map) {
    final requestId = (map['requestId'] as String?)?.trim() ?? '';
    if (requestId.isEmpty) {
      throw const FormatException('Recommendation request id is missing.');
    }

    final outcome = AiRecommendationOutcomeMapping.fromApi(
      (map['outcome'] as String?) ?? '',
    );

    final reasoning = (map['reasoning'] as String?)?.trim() ?? '';
    final ownerAdvice = (map['ownerAdvice'] as String?)?.trim() ?? '';
    final safetyNotice = (map['safetyNotice'] as String?)?.trim() ?? '';
    if (reasoning.isEmpty || ownerAdvice.isEmpty || safetyNotice.isEmpty) {
      throw const FormatException('Recommendation text fields are incomplete.');
    }

    RecommendedServiceSummary? primaryService;
    final rawPrimary = map['primaryService'];
    if (rawPrimary != null) {
      if (rawPrimary is! Map) {
        throw const FormatException('Primary service is invalid.');
      }
      primaryService = RecommendedServiceSummary.fromMap(
        Map<String, dynamic>.from(rawPrimary),
      );
    }

    final rawAdditional = map['additionalServices'];
    if (rawAdditional is! List) {
      throw const FormatException('Additional services are invalid.');
    }
    final additionalServices = <RecommendedServiceSummary>[
      for (final item in rawAdditional)
        if (item is Map)
          RecommendedServiceSummary.fromMap(Map<String, dynamic>.from(item))
        else
          throw const FormatException('Additional service is invalid.'),
    ];

    final codes = additionalServices.map((service) => service.code).toList();
    if (codes.toSet().length != codes.length) {
      throw const FormatException('Additional services contain duplicates.');
    }

    final rawRequirements = map['sitterRequirements'];
    if (rawRequirements is! List) {
      throw const FormatException('Sitter requirements are invalid.');
    }
    final sitterRequirements = <String>[
      for (final item in rawRequirements)
        if (item is String && item.trim().isNotEmpty)
          item.trim()
        else
          throw const FormatException('Sitter requirement is invalid.'),
    ];

    if (outcome == AiRecommendationOutcome.serviceRecommendation) {
      if (primaryService == null) {
        throw const FormatException(
          'Service recommendation requires a primary service.',
        );
      }
    } else {
      if (primaryService != null) {
        throw const FormatException(
          'Urgent veterinary outcome cannot include a service.',
        );
      }
      if (additionalServices.isNotEmpty) {
        throw const FormatException(
          'Urgent veterinary outcome cannot include additional services.',
        );
      }
      if (sitterRequirements.isNotEmpty) {
        throw const FormatException(
          'Urgent veterinary outcome cannot include sitter requirements.',
        );
      }
    }

    return AiServiceRecommendationResult(
      requestId: requestId,
      outcome: outcome,
      primaryService: primaryService,
      additionalServices: additionalServices,
      reasoning: reasoning,
      sitterRequirements: sitterRequirements,
      ownerAdvice: ownerAdvice,
      safetyNotice: safetyNotice,
    );
  }
}
