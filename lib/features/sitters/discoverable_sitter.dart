import '../services/sitter_service_model.dart';

/// Active PawPal provider shown on the owner discovery list.
class DiscoverableSitter {
  DiscoverableSitter({
    required String id,
    required String fullName,
    String? suburb,
    String? postcode,
    String? serviceDescription,
    double? latitude,
    double? longitude,
    required List<SitterServiceModel> offerings,
  }) : id = id.trim(),
       fullName = fullName.trim(),
       suburb = _trimOrNull(suburb),
       postcode = _trimOrNull(postcode),
       serviceDescription = _trimOrNull(serviceDescription),
       latitude = _validatedLatitude(latitude),
       longitude = _validatedLongitude(longitude),
       offerings = List.unmodifiable(
         offerings.where((offering) => offering.isActive),
       ) {
    if (this.id.isEmpty) {
      throw const FormatException('Sitter id is missing.');
    }
    if (this.fullName.isEmpty) {
      throw const FormatException('Sitter full name is missing.');
    }
  }

  final String id;
  final String fullName;
  final String? suburb;
  final String? postcode;
  final String? serviceDescription;
  final double? latitude;
  final double? longitude;
  final List<SitterServiceModel> offerings;

  /// True when both stored coordinates are present and valid.
  bool get isMapReady => latitude != null && longitude != null;

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _validatedLatitude(double? value) {
    if (value == null) return null;
    if (value < -90 || value > 90) {
      throw const FormatException('Latitude must be between -90 and 90.');
    }
    return value;
  }

  static double? _validatedLongitude(double? value) {
    if (value == null) return null;
    if (value < -180 || value > 180) {
      throw const FormatException('Longitude must be between -180 and 180.');
    }
    return value;
  }
}

/// Groups active offerings into one [DiscoverableSitter] per sitter.
///
/// Expects offerings already ordered by catalogue preference where practical.
/// Sitters without any active offering (and joined profile/service) are omitted.
List<DiscoverableSitter> groupOfferingsIntoDiscoverableSitters(
  List<SitterServiceModel> offerings,
) {
  final grouped = <String, List<SitterServiceModel>>{};
  final profiles =
      <
        String,
        ({
          String fullName,
          String? suburb,
          String? postcode,
          String? serviceDescription,
          double? latitude,
          double? longitude,
        })
      >{};

  for (final offering in offerings) {
    if (!offering.isActive) continue;
    final service = offering.service;
    final sitter = offering.sitter;
    if (service == null || !service.isActive || sitter == null) continue;

    grouped
        .putIfAbsent(offering.sitterId, () => <SitterServiceModel>[])
        .add(offering);
    profiles.putIfAbsent(
      offering.sitterId,
      () => (
        fullName: sitter.fullName,
        suburb: sitter.suburb,
        postcode: sitter.postcode,
        serviceDescription: sitter.serviceDescription,
        latitude: sitter.latitude,
        longitude: sitter.longitude,
      ),
    );
  }

  final sitters = <DiscoverableSitter>[
    for (final entry in grouped.entries)
      if (entry.value.isNotEmpty)
        DiscoverableSitter(
          id: entry.key,
          fullName: profiles[entry.key]!.fullName,
          suburb: profiles[entry.key]!.suburb,
          postcode: profiles[entry.key]!.postcode,
          serviceDescription: profiles[entry.key]!.serviceDescription,
          latitude: profiles[entry.key]!.latitude,
          longitude: profiles[entry.key]!.longitude,
          offerings: entry.value,
        ),
  ];

  sitters.sort(
    (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
  );
  return sitters;
}

/// Filters discovery results by optional catalogue service and local text query.
List<DiscoverableSitter> filterDiscoverableSitters(
  List<DiscoverableSitter> sitters, {
  String? serviceId,
  String query = '',
}) {
  final trimmedServiceId = serviceId?.trim();
  final hasServiceFilter =
      trimmedServiceId != null && trimmedServiceId.isNotEmpty;
  final normalisedQuery = query.trim().toLowerCase();
  final hasQuery = normalisedQuery.isNotEmpty;

  final filtered = <DiscoverableSitter>[];

  for (final sitter in sitters) {
    var offerings = sitter.offerings;
    if (hasServiceFilter) {
      offerings = [
        for (final offering in offerings)
          if (offering.serviceId == trimmedServiceId) offering,
      ];
      if (offerings.isEmpty) continue;
    }

    if (hasQuery && !_matchesSearch(sitter, normalisedQuery)) {
      continue;
    }

    if (identical(offerings, sitter.offerings)) {
      filtered.add(sitter);
    } else {
      filtered.add(
        DiscoverableSitter(
          id: sitter.id,
          fullName: sitter.fullName,
          suburb: sitter.suburb,
          postcode: sitter.postcode,
          serviceDescription: sitter.serviceDescription,
          latitude: sitter.latitude,
          longitude: sitter.longitude,
          offerings: offerings,
        ),
      );
    }
  }

  return filtered;
}

/// Sitters with both valid latitude and longitude for map markers.
List<DiscoverableSitter> mapReadySitters(List<DiscoverableSitter> sitters) {
  return [
    for (final sitter in sitters)
      if (sitter.isMapReady) sitter,
  ];
}

bool _matchesSearch(DiscoverableSitter sitter, String normalisedQuery) {
  if (sitter.fullName.toLowerCase().contains(normalisedQuery)) {
    return true;
  }
  final suburb = sitter.suburb;
  if (suburb != null && suburb.toLowerCase().contains(normalisedQuery)) {
    return true;
  }
  final postcode = sitter.postcode;
  if (postcode != null && postcode.toLowerCase().contains(normalisedQuery)) {
    return true;
  }
  return false;
}
