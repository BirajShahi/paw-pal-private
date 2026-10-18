import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:paw_pal/features/university_api/university_api_client.dart';
import 'package:paw_pal/features/university_api/university_api_config.dart';
import 'package:paw_pal/features/university_api/university_api_providers.dart';

/// Returns one scripted response for each request.
class _ScriptedHttp extends http.BaseClient {
  _ScriptedHttp(this.onSend);

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

/// Never answers, so the client timeout can be tested.
class _HangingHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}

void main() {
  test('auth and dashboard URLs use the configurable class location', () {
    expect(
      UniversityApiConfig.authUri().toString(),
      'https://nit3213apinew.onrender.com/footscray/auth',
    );
    expect(
      UniversityApiConfig.dashboardUri('plants').toString(),
      'https://nit3213apinew.onrender.com/dashboard/plants',
    );
  });

  test('readKeypass returns the keypass field', () {
    expect(readKeypass('{"keypass":"plants"}'), 'plants');
  });

  test('readKeypass rejects a body without a keypass', () {
    expect(
      () => readKeypass('{"ok":true}'),
      throwsA(isA<UniversityApiException>()),
    );
  });

  test('readEntities keeps every property, including description', () {
    const body = '''
    {
      "entities": [
        {"name": "Fern", "description": "A shade plant", "count": 2}
      ],
      "entityTotal": 1
    }
    ''';

    final entities = readEntities(body);

    expect(entities, hasLength(1));
    expect(entities.single.properties['name'], 'Fern');
    expect(entities.single.description, 'A shade plant');
    expect(entities.single.properties['count'], 2);
    expect(entities.single.listTitle(0), 'Fern');
  });

  test('wrong login status codes are explained as incorrect details', () {
    expect(loginFailureMessage(404), contains('not accepted'));
    expect(loginFailureMessage(401), contains('not accepted'));
    expect(loginFailureMessage(500), contains('error 500'));
  });

  test('provider creates a university API client', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(universityApiClientProvider),
      isA<UniversityApiClient>(),
    );
  });

  test(
    'login posts the student ID and first name and returns the keypass',
    () async {
      final client = UniversityApiClient(
        httpClient: _ScriptedHttp((request) async {
          final sent = request as http.Request;
          expect(sent.method, 'POST');
          expect(sent.url.path, '/footscray/auth');
          final body = jsonDecode(sent.body) as Map<String, dynamic>;
          expect(body['username'], 's1234567');
          expect(body['password'], 'Ada');
          return http.Response('{"keypass":"plants"}', 200);
        }),
      );

      expect(
        await client.login(username: ' s1234567 ', password: ' Ada '),
        'plants',
      );
    },
  );

  test('login explains rejected details', () async {
    final client = UniversityApiClient(
      httpClient: _ScriptedHttp((request) async => http.Response('', 401)),
    );

    expect(
      () => client.login(username: 's0000000', password: 'Nope'),
      throwsA(
        isA<UniversityApiException>().having(
          (error) => error.message,
          'message',
          contains('not accepted'),
        ),
      ),
    );
  });

  test('login explains a response that cannot be read', () async {
    final client = UniversityApiClient(
      httpClient: _ScriptedHttp(
        (request) async => http.Response('not-json', 200),
      ),
    );

    expect(
      () => client.login(username: 's1234567', password: 'Ada'),
      throwsA(
        isA<UniversityApiException>().having(
          (error) => error.message,
          'message',
          contains('could not be read'),
        ),
      ),
    );
  });

  test('login explains a timeout', () async {
    final client = UniversityApiClient(
      httpClient: _HangingHttp(),
      timeout: const Duration(milliseconds: 20),
    );

    expect(
      () => client.login(username: 's1234567', password: 'Ada'),
      throwsA(
        isA<UniversityApiException>().having(
          (error) => error.message,
          'message',
          contains('too long'),
        ),
      ),
    );
  });

  test('fetchEntities reads the dashboard list for the keypass', () async {
    final client = UniversityApiClient(
      httpClient: _ScriptedHttp((request) async {
        final sent = request as http.Request;
        expect(sent.method, 'GET');
        expect(sent.url.path, '/dashboard/plants');
        return http.Response(
          jsonEncode({
            'entities': [
              {'name': 'Fern', 'description': 'A shade plant'},
            ],
          }),
          200,
        );
      }),
    );

    final entities = await client.fetchEntities('plants');

    expect(entities, hasLength(1));
    expect(entities.single.properties['name'], 'Fern');
    expect(entities.single.description, 'A shade plant');
  });

  test('fetchEntities explains a failed dashboard response', () async {
    final client = UniversityApiClient(
      httpClient: _ScriptedHttp((request) async => http.Response('', 404)),
    );

    expect(
      () => client.fetchEntities('missing'),
      throwsA(
        isA<UniversityApiException>().having(
          (error) => error.message,
          'message',
          contains('keypass'),
        ),
      ),
    );
  });

  test('fetchEntities explains a dashboard body that cannot be read', () async {
    final client = UniversityApiClient(
      httpClient: _ScriptedHttp((request) async => http.Response('{', 200)),
    );

    expect(
      () => client.fetchEntities('plants'),
      throwsA(
        isA<UniversityApiException>().having(
          (error) => error.message,
          'message',
          contains('could not be read'),
        ),
      ),
    );
  });
}
