import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:paw_pal/core/router/app_router.dart';
import 'package:paw_pal/features/university_api/university_api_client.dart';
import 'package:paw_pal/features/university_api/university_api_login_screen.dart';
import 'package:paw_pal/features/university_api/university_entity.dart';
import 'package:paw_pal/features/university_api/university_entity_detail_screen.dart';
import 'package:paw_pal/features/university_api/university_entity_list_screen.dart';

/// Records each request and returns a scripted response.
class _FakeHttp extends http.BaseClient {
  _FakeHttp(this.onSend);

  final Future<http.Response> Function(http.BaseRequest request) onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await onSend(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

Future<void> _pumpLogin(WidgetTester tester, UniversityApiClient? client) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: UniversityApiLoginScreen(client: client)),
    ),
  );
}

void main() {
  testWidgets('empty login shows validation messages', (tester) async {
    await _pumpLogin(tester, null);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your student ID.'), findsOneWidget);
    expect(find.text('Enter your first name.'), findsOneWidget);
  });

  testWidgets('incorrect login details are explained', (tester) async {
    final client = UniversityApiClient(
      httpClient: _FakeHttp((request) async => http.Response('', 404)),
    );
    await _pumpLogin(tester, client);

    await tester.enterText(find.byType(TextFormField).at(0), 's0000000');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nope');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not accepted'), findsOneWidget);
  });

  testWidgets('a failed connection is explained', (tester) async {
    final client = UniversityApiClient(
      httpClient: _FakeHttp((request) async {
        throw http.ClientException('blocked');
      }),
    );
    await _pumpLogin(tester, client);

    await tester.enterText(find.byType(TextFormField).at(0), 's0000000');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nope');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not reach'), findsOneWidget);
  });

  testWidgets('successful login lists entities and shows every property', (
    tester,
  ) async {
    final client = UniversityApiClient(
      httpClient: _FakeHttp((request) async {
        final sent = request as http.Request;
        if (sent.url.path.endsWith('/auth')) {
          expect(sent.body, contains('"username":"s1234567"'));
          expect(sent.body, contains('"password":"Ada"'));
          return http.Response('{"keypass":"plants"}', 200);
        }
        expect(sent.url.path, '/dashboard/plants');
        return http.Response(
          jsonEncode({
            'entities': [
              {'name': 'Fern', 'description': 'A shade plant', 'height': 2},
            ],
            'entityTotal': 1,
          }),
          200,
        );
      }),
    );

    final router = GoRouter(
      initialLocation: AppRoutes.universityApi,
      routes: [
        GoRoute(
          path: AppRoutes.universityApi,
          builder: (context, state) => UniversityApiLoginScreen(client: client),
        ),
        GoRoute(
          path: AppRoutes.universityApiEntities,
          builder: (context, state) {
            final extra = state.extra;
            return UniversityEntityListScreen(
              entities: extra is List<UniversityEntity> ? extra : null,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.universityApiEntity,
          builder: (context, state) {
            final extra = state.extra;
            return UniversityEntityDetailScreen(
              entity: extra is UniversityEntity ? extra : null,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 's1234567');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ada');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Fern'), findsOneWidget);
    expect(find.textContaining('A shade plant'), findsOneWidget);

    await tester.tap(find.text('Fern'));
    await tester.pumpAndSettle();

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('A shade plant'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
