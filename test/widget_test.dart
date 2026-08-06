import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:paw_pal/main.dart';

class _MemoryLocalStorage extends LocalStorage {
  const _MemoryLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<void> persistSession(String persistSessionString) async {}

  @override
  Future<void> removePersistedSession() async {}
}

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async => _map[key];

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: FlutterAuthClientOptions(
        localStorage: const _MemoryLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
    );
  });

  testWidgets('PawPal app loads home screen when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PawPalApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PawPal'), findsOneWidget);
    expect(find.text('Welcome to PawPal'), findsOneWidget);
  });
}
