import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/features/services/service_category.dart';
import 'package:paw_pal/features/services/sitter_profile_summary.dart';
import 'package:paw_pal/features/services/sitter_service_model.dart';
import 'package:paw_pal/features/services/sitter_service_providers.dart';
import 'package:paw_pal/features/services/sitter_service_repository.dart';

void main() {
  Map<String, dynamic> serviceMap() {
    return {
      'id': 'svc-1',
      'code': 'full_grooming',
      'name': 'Full Grooming',
      'category': 'grooming',
      'description': 'A complete grooming service for pets that need cleaning.',
      'included_items': ['Wash and shampoo'],
      'recommendation_tags': ['dirty coat'],
      'can_be_add_on': false,
      'is_active': true,
      'display_order': 10,
      'created_at': '2026-01-01T10:00:00Z',
      'updated_at': '2026-01-01T10:00:00Z',
    };
  }

  Map<String, dynamic> profileMap({
    String? id,
    String? fullName,
    Object? suburb = 'Carlton',
    Object? postcode = '3053',
    Object? serviceDescription = 'Experienced dog walker',
  }) {
    return {
      'id': id ?? 'sitter-1',
      'full_name': fullName ?? 'Alex Walker',
      'suburb': suburb,
      'postcode': postcode,
      'service_description': serviceDescription,
    };
  }

  Map<String, dynamic> offeringMap({
    Object? price = 45.5,
    Object? notes = 'Gentle handling',
    Object? duration = 60,
    bool includeService = true,
    Object? profiles,
    bool includeProfiles = false,
    String? id,
    String? sitterId,
    String? serviceId,
  }) {
    return {
      'id': id ?? 'offer-1',
      'sitter_id': sitterId ?? 'sitter-1',
      'service_id': serviceId ?? 'svc-1',
      'price': price,
      'estimated_duration_minutes': duration,
      'service_notes': notes,
      'is_active': true,
      'created_at': '2026-01-02T10:00:00Z',
      'updated_at': '2026-01-03T10:00:00Z',
      if (includeService) 'services': serviceMap(),
      if (includeProfiles) 'profiles': profiles ?? profileMap(),
    };
  }

  group('SitterProfileSummary.fromMap', () {
    test('maps a complete sitter summary', () {
      final sitter = SitterProfileSummary.fromMap(profileMap());

      expect(sitter.id, 'sitter-1');
      expect(sitter.fullName, 'Alex Walker');
      expect(sitter.suburb, 'Carlton');
      expect(sitter.postcode, '3053');
      expect(sitter.serviceDescription, 'Experienced dog walker');
    });

    test('converts blank optional values to null', () {
      final sitter = SitterProfileSummary.fromMap(
        profileMap(suburb: '   ', postcode: '', serviceDescription: '  '),
      );

      expect(sitter.suburb, isNull);
      expect(sitter.postcode, isNull);
      expect(sitter.serviceDescription, isNull);
    });

    test('rejects missing or blank required sitter values', () {
      expect(
        () => SitterProfileSummary.fromMap(profileMap(id: ' ')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterProfileSummary.fromMap(profileMap(fullName: '')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SitterServiceModel.fromMap', () {
    test('maps a complete offering with nested service', () {
      final offering = SitterServiceModel.fromMap(offeringMap());

      expect(offering.id, 'offer-1');
      expect(offering.sitterId, 'sitter-1');
      expect(offering.serviceId, 'svc-1');
      expect(offering.price, 45.5);
      expect(offering.estimatedDurationMinutes, 60);
      expect(offering.serviceNotes, 'Gentle handling');
      expect(offering.isActive, isTrue);
      expect(offering.service?.code, 'full_grooming');
      expect(offering.service?.category, ServiceCategory.grooming);
      expect(offering.sitter, isNull);
    });

    test('maps nested profile data when available', () {
      final offering = SitterServiceModel.fromMap(
        offeringMap(includeProfiles: true),
      );

      expect(offering.sitter?.fullName, 'Alex Walker');
      expect(offering.sitter?.suburb, 'Carlton');
    });

    test('maps nested sitter key when available', () {
      final map = offeringMap();
      map['sitter'] = profileMap(fullName: 'Sam Sitter');
      final offering = SitterServiceModel.fromMap(map);

      expect(offering.sitter?.fullName, 'Sam Sitter');
    });

    test('still works without a joined sitter', () {
      final offering = SitterServiceModel.fromMap(
        offeringMap(includeService: true, includeProfiles: false),
      );

      expect(offering.service?.code, 'full_grooming');
      expect(offering.sitter, isNull);
    });

    test('converts numeric database prices with num.toDouble()', () {
      final fromInt = SitterServiceModel.fromMap(offeringMap(price: 40));
      final fromDouble = SitterServiceModel.fromMap(offeringMap(price: 40.25));

      expect(fromInt.price, 40.0);
      expect(fromDouble.price, 40.25);
    });

    test('converts blank service notes to null', () {
      final offering = SitterServiceModel.fromMap(offeringMap(notes: '   '));
      expect(offering.serviceNotes, isNull);
    });

    test('rejects empty IDs', () {
      expect(
        () => SitterServiceModel.fromMap(offeringMap(id: '')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterServiceModel.fromMap(offeringMap(sitterId: ' ')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterServiceModel.fromMap(offeringMap(serviceId: '')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid price', () {
      expect(
        () => SitterServiceModel.fromMap(offeringMap(price: 0)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterServiceModel.fromMap(offeringMap(price: -1)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterServiceModel.fromMap(offeringMap(price: 1001)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid duration', () {
      expect(
        () => SitterServiceModel.fromMap(offeringMap(duration: 14)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SitterServiceModel.fromMap(offeringMap(duration: 1441)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('normalizeMatchServiceCode', () {
    test('trims and lowercases the service code', () {
      expect(normalizeMatchServiceCode('  Dog_Walking  '), 'dog_walking');
    });

    test('rejects a blank service code', () {
      expect(
        () => normalizeMatchServiceCode('   '),
        throwsA(isA<SitterServiceException>()),
      );
    });
  });

  group('SitterServiceRepository validation', () {
    test('rejects blank service id', () {
      expect(
        () => SitterServiceRepository.validateSitterServiceFields(
          serviceId: ' ',
          price: 25,
        ),
        throwsA(isA<SitterServiceException>()),
      );
    });

    test('rejects invalid price and duration', () {
      expect(
        () => SitterServiceRepository.validateSitterServiceFields(
          serviceId: 'svc-1',
          price: 0,
        ),
        throwsA(isA<SitterServiceException>()),
      );
      expect(
        () => SitterServiceRepository.validateSitterServiceFields(
          serviceId: 'svc-1',
          price: 20,
          estimatedDurationMinutes: 10,
        ),
        throwsA(isA<SitterServiceException>()),
      );
    });

    test('trims blank notes to null', () {
      final payload = SitterServiceRepository.validateSitterServiceFields(
        serviceId: 'svc-1',
        price: 30,
        serviceNotes: '  ',
      );
      expect(payload['service_notes'], isNull);
    });
  });
}
