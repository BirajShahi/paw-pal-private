import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'university_api_config.dart';
import 'university_entity.dart';

/// A problem talking to the university API, with a message safe to show.
class UniversityApiException implements Exception {
  const UniversityApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the NIT3213 API. PawPal's Supabase client is not used here.
class UniversityApiClient {
  UniversityApiClient({
    this.httpClient,
    this.timeout = const Duration(seconds: 60),
  });

  /// Optional client so tests can substitute a fake. Screens can omit it.
  final http.Client? httpClient;

  /// Render's free servers can take a while to wake up.
  ///
  /// Tests pass a shorter [timeout] so a hung request fails quickly.
  final Duration timeout;

  /// Signs in with the student ID ([username]) and first name ([password]).
  ///
  /// Returns the `keypass` from the JSON body. That value is required for
  /// the dashboard request.
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final response = await _send(() {
      return _post(
        UniversityApiConfig.authUri(),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username.trim(),
          'password': password.trim(),
        }),
      );
    });

    if (response.statusCode != 200) {
      throw UniversityApiException(loginFailureMessage(response.statusCode));
    }

    return readKeypass(response.body);
  }

  /// Loads dashboard entities for a [keypass] from a successful login.
  Future<List<UniversityEntity>> fetchEntities(String keypass) async {
    final response = await _send(() {
      return _get(
        UniversityApiConfig.dashboardUri(keypass),
        headers: const {'Accept': 'application/json'},
      );
    });

    if (response.statusCode != 200) {
      throw UniversityApiException(
        dashboardFailureMessage(response.statusCode),
      );
    }

    return readEntities(response.body);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const UniversityApiException(
        'The university API took too long to respond. Please try again.',
      );
    } on http.ClientException {
      // A browser can also report a blocked response, such as missing CORS
      // headers, as a client exception.
      throw const UniversityApiException(
        'Could not reach the university API. Check your connection and try again.',
      );
    }
  }

  Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final client = httpClient;
    if (client != null) {
      return client.post(url, headers: headers, body: body);
    }
    return http.post(url, headers: headers, body: body);
  }

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) {
    final client = httpClient;
    if (client != null) {
      return client.get(url, headers: headers);
    }
    return http.get(url, headers: headers);
  }
}

/// Message for a failed POST /{classLocation}/auth response.
String loginFailureMessage(int statusCode) {
  // This API responds with 401, 403, or 404 when the details are wrong.
  if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
    return 'Those login details were not accepted. '
        'Check your student ID and first name.';
  }
  if (statusCode == 400) {
    return 'The university API could not understand the login request.';
  }
  return 'The university API could not sign you in (error $statusCode).';
}

/// Message for a failed GET /dashboard/{keypass} response.
String dashboardFailureMessage(int statusCode) {
  if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
    return 'The dashboard could not be opened. The keypass may be invalid.';
  }
  return 'The dashboard could not be loaded (error $statusCode).';
}

/// Reads `keypass` from a successful auth JSON body.
String readKeypass(String body) {
  final decoded = _decodeMap(body);
  final keypass = decoded['keypass']?.toString().trim() ?? '';
  if (keypass.isEmpty) {
    throw const UniversityApiException('The API did not return a keypass.');
  }
  return keypass;
}

/// Reads the `entities` array from a dashboard JSON body.
List<UniversityEntity> readEntities(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const UniversityApiException(
      'The university API returned a response that could not be read.',
    );
  }

  final List<dynamic> raw;
  if (decoded is List) {
    raw = decoded;
  } else if (decoded is Map) {
    final entities = decoded['entities'];
    if (entities is! List) {
      throw const UniversityApiException(
        'The dashboard response did not include an entities list.',
      );
    }
    raw = entities;
  } else {
    throw const UniversityApiException(
      'The dashboard response was not in the expected format.',
    );
  }

  return [
    for (final item in raw)
      if (item is Map)
        UniversityEntity(Map<String, dynamic>.from(item))
      else
        UniversityEntity({'value': item}),
  ];
}

Map<String, dynamic> _decodeMap(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const UniversityApiException(
      'The university API returned a response that could not be read.',
    );
  }
  if (decoded is! Map) {
    throw const UniversityApiException(
      'The university API returned a response that could not be read.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}
