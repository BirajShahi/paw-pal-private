import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_pal/features/pets/pet_delete_confirmation.dart';

void main() {
  testWidgets('cancelling does not confirm deletion', (tester) async {
    var confirmed = false;
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  confirmed = await showDeletePetConfirmationDialog(
                    context,
                    petName: 'Buddy',
                    onConfirmed: () async {
                      deleteCalls += 1;
                    },
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(deleteCalls, 0);
  });

  testWidgets('confirming calls the repository once', (tester) async {
    var confirmed = false;
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  confirmed = await showDeletePetConfirmationDialog(
                    context,
                    petName: 'Buddy',
                    onConfirmed: () async {
                      deleteCalls += 1;
                    },
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(deleteCalls, 1);
  });

  testWidgets('delete button is disabled while processing', (tester) async {
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showDeletePetConfirmationDialog(
                    context,
                    petName: 'Buddy',
                    onConfirmed: () async {
                      deleteCalls += 1;
                      await Future<void>.delayed(
                        const Duration(milliseconds: 200),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();

    final deleteButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Delete'),
    );
    expect(deleteButton.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
  });

  testWidgets('failed deletion displays an error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showDeletePetConfirmationDialog(
                    context,
                    petName: 'Buddy',
                    onConfirmed: () async {
                      throw Exception('Network error');
                    },
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Network error'), findsOneWidget);
    expect(find.text('Delete Buddy?'), findsOneWidget);
  });

  testWidgets('successful deletion closes the dialog', (tester) async {
    var listInvalidated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  final deleted = await showDeletePetConfirmationDialog(
                    context,
                    petName: 'Buddy',
                    onConfirmed: () async {},
                  );
                  if (deleted) {
                    listInvalidated = true;
                  }
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Buddy?'), findsNothing);
    expect(listInvalidated, isTrue);
  });
}
