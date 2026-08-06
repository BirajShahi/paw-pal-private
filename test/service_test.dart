import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/features/services/service_category.dart';
import 'package:paw_pal/features/services/service_model.dart';

void main() {
  Map<String, dynamic> validMap({
    String category = 'grooming',
    Object? includedItems,
    Object? recommendationTags,
    int displayOrder = 10,
    String? id,
    String? code,
    String? name,
    String? description,
  }) {
    return {
      'id': id ?? 'service-1',
      'code': code ?? 'full_grooming',
      'name': name ?? 'Full Grooming',
      'category': category,
      'description':
          description ??
          'A complete grooming service for pets that need cleaning.',
      'included_items': includedItems ?? ['Wash and shampoo', 'Blow-dry'],
      'recommendation_tags': recommendationTags ?? ['dirty coat', 'long coat'],
      'can_be_add_on': false,
      'is_active': true,
      'display_order': displayOrder,
      'created_at': '2026-01-01T10:00:00Z',
      'updated_at': '2026-01-02T10:00:00Z',
    };
  }

  group('ServiceCategory', () {
    test('maps database values', () {
      expect(
        ServiceCategory.fromDatabaseValue('grooming'),
        ServiceCategory.grooming,
      );
      expect(
        ServiceCategory.fromDatabaseValue('walking'),
        ServiceCategory.walking,
      );
      expect(
        ServiceCategory.fromDatabaseValue('home_care'),
        ServiceCategory.homeCare,
      );
      expect(
        ServiceCategory.fromDatabaseValue('sitting'),
        ServiceCategory.sitting,
      );
    });

    test('exposes database and display values', () {
      expect(ServiceCategory.homeCare.databaseValue, 'home_care');
      expect(ServiceCategory.homeCare.displayName, 'Home Care');
      expect(ServiceCategory.walking.displayName, 'Dog Walking');
      expect(ServiceCategory.sitting.displayName, 'Pet Sitting');
      expect(ServiceCategory.grooming.displayName, 'Grooming');
    });

    test('rejects an invalid category', () {
      expect(
        () => ServiceCategory.fromDatabaseValue('boarding'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ServiceModel.fromMap', () {
    test('maps a complete services row', () {
      final service = ServiceModel.fromMap(validMap());

      expect(service.id, 'service-1');
      expect(service.code, 'full_grooming');
      expect(service.name, 'Full Grooming');
      expect(service.category, ServiceCategory.grooming);
      expect(service.description, contains('complete grooming'));
      expect(service.includedItems, ['Wash and shampoo', 'Blow-dry']);
      expect(service.recommendationTags, ['dirty coat', 'long coat']);
      expect(service.canBeAddOn, isFalse);
      expect(service.isActive, isTrue);
      expect(service.displayOrder, 10);
    });

    test('maps PostgreSQL text arrays', () {
      final service = ServiceModel.fromMap(
        validMap(
          includedItems: <dynamic>['Nail clipping', 'Ear cleaning'],
          recommendationTags: <dynamic>['overgrown nails', 'nail care'],
        ),
      );

      expect(service.includedItems, ['Nail clipping', 'Ear cleaning']);
      expect(service.recommendationTags, ['overgrown nails', 'nail care']);
      expect(() => service.includedItems.add('x'), throwsUnsupportedError);
    });

    test('converts home_care category', () {
      final service = ServiceModel.fromMap(validMap(category: 'home_care'));
      expect(service.category, ServiceCategory.homeCare);
      expect(service.category.displayName, 'Home Care');
    });

    test('rejects empty required values', () {
      expect(
        () => ServiceModel.fromMap(validMap(id: '')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ServiceModel.fromMap(validMap(code: ' ')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ServiceModel.fromMap(validMap(name: '')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ServiceModel.fromMap(validMap(description: '')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a negative display order', () {
      expect(
        () => ServiceModel.fromMap(validMap(displayOrder: -1)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('display order'),
          ),
        ),
      );
    });

    test('rejects an unsupported category', () {
      expect(
        () => ServiceModel.fromMap(validMap(category: 'training')),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
