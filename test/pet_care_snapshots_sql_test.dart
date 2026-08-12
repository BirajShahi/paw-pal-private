import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('t10_pet_care_snapshots.sql', () {
    late String sql;

    setUpAll(() {
      sql = File(
        'database/t10_pet_care_snapshots.sql',
      ).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('adds nullable pet care snapshot columns with length limits', () {
      expect(sql, contains('pet_medical_notes_snapshot'));
      expect(sql, contains('pet_behaviour_notes_snapshot'));
      expect(sql, contains('pet_care_notes_snapshot'));
      expect(sql, contains('char_length(pet_medical_notes_snapshot) <= 1000'));
      expect(
        sql,
        contains('char_length(pet_behaviour_notes_snapshot) <= 1000'),
      );
      expect(sql, contains('char_length(pet_care_notes_snapshot) <= 1000'));
    });

    test('prepare trigger snapshots notes from the owner pet server-side', () {
      expect(
        sql,
        contains('create or replace function public.prepare_pawpal_booking()'),
      );
      expect(sql, contains('pets.medical_notes'));
      expect(sql, contains('pets.behaviour_notes'));
      expect(sql, contains('pets.care_notes'));
      expect(
        sql,
        contains('new.pet_medical_notes_snapshot := selected_medical_notes'),
      );
      expect(
        sql,
        contains(
          'new.pet_behaviour_notes_snapshot := selected_behaviour_notes',
        ),
      );
      expect(
        sql,
        contains('new.pet_care_notes_snapshot := selected_care_notes'),
      );
    });

    test('update trigger keeps care note snapshots immutable', () {
      expect(
        sql,
        contains(
          'create or replace function public.validate_pawpal_booking_update()',
        ),
      );
      expect(sql, contains('is distinct from old.pet_medical_notes_snapshot'));
      expect(
        sql,
        contains('is distinct from old.pet_behaviour_notes_snapshot'),
      );
      expect(sql, contains('is distinct from old.pet_care_notes_snapshot'));
      expect(sql, contains('Original booking details cannot be changed.'));
    });

    test('does not weaken pets RLS or add sitter pet browsing', () {
      expect(sql.toLowerCase(), isNot(contains('on public.pets')));
      expect(sql.toLowerCase(), isNot(contains('sitters can view')));
      expect(
        sql.toLowerCase(),
        isNot(contains('grant select on table public.pets')),
      );
    });
  });
}
