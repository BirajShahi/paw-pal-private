import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/features/auth/auth_role.dart';
import 'package:paw_pal/features/profile/profile_model.dart';
import 'package:paw_pal/features/profile/profile_repository.dart';

void main() {
  group('ProfileModel.fromMap', () {
    test('maps a valid profiles row', () {
      final profile = ProfileModel.fromMap({
        'id': 'user-1',
        'role': 'sitter',
        'full_name': 'Alex Smith',
        'suburb': 'Carlton',
        'postcode': '3053',
        'service_description': 'Dog walks',
        'hourly_price': 25,
        'latitude': -37.8,
        'longitude': 144.9,
      });

      expect(profile.id, 'user-1');
      expect(profile.role, AuthRole.sitter);
      expect(profile.fullName, 'Alex Smith');
      expect(profile.suburb, 'Carlton');
      expect(profile.postcode, '3053');
      expect(profile.serviceDescription, 'Dog walks');
      expect(profile.hourlyPrice, 25);
      expect(profile.latitude, -37.8);
      expect(profile.longitude, 144.9);
    });

    test('keeps nullable fields null', () {
      final profile = ProfileModel.fromMap({
        'id': 'user-2',
        'role': 'owner',
        'full_name': 'Jamie Lee',
        'suburb': null,
        'postcode': null,
        'service_description': null,
        'hourly_price': null,
        'latitude': null,
        'longitude': null,
      });

      expect(profile.role, AuthRole.owner);
      expect(profile.suburb, isNull);
      expect(profile.postcode, isNull);
      expect(profile.serviceDescription, isNull);
      expect(profile.hourlyPrice, isNull);
      expect(profile.latitude, isNull);
      expect(profile.longitude, isNull);
    });

    test('rejects an invalid role', () {
      expect(
        () => ProfileModel.fromMap({
          'id': 'user-3',
          'role': 'admin',
          'full_name': 'Bad Role',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('role'),
          ),
        ),
      );
    });
  });

  group('ProfileRepository validation', () {
    test('rejects a negative hourly price', () {
      expect(
        () => ProfileRepository.validateSitterCoordinatesAndPrice(
          hourlyPrice: -1,
        ),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.message,
            'message',
            contains('Hourly price'),
          ),
        ),
      );
    });

    test('rejects latitude outside -90..90', () {
      expect(
        () => ProfileRepository.validateSitterCoordinatesAndPrice(latitude: 91),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.message,
            'message',
            contains('Latitude'),
          ),
        ),
      );
    });

    test('rejects longitude outside -180..180', () {
      expect(
        () => ProfileRepository.validateSitterCoordinatesAndPrice(
          longitude: -181,
        ),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.message,
            'message',
            contains('Longitude'),
          ),
        ),
      );
    });

    test('allows null coordinates and price', () {
      expect(
        () => ProfileRepository.validateSitterCoordinatesAndPrice(),
        returnsNormally,
      );
    });
  });
}
