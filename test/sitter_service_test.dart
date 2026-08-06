import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/features/services/service_category.dart';
import 'package:paw_pal/features/services/sitter_service_model.dart';
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

  Map<String, dynamic> offeringMap({
    Object? price = 45.5,
    Object? notes = 'Gentle handling',
    Object? duration = 60,
    bool includeService = true,
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
    };
  }

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
