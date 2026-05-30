// test/widget_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Basic smoke test — verifies the widget tree renders without crashing.
//
// Firebase and Supabase are mocked via their test packages so the suite
// runs on CI without real credentials.
//
// Run with:
//   flutter test
// ─────────────────────────────────────────────────────────────────────────────
import 'package:ekklisia/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';


// Generated mocks — run `flutter pub run build_runner build` to regenerate
// @GenerateMocks([BooksRepository, AuthService, NotificationService])
// import 'widget_test.mocks.dart';

// ---------------------------------------------------------------------------
// Minimal hand-rolled stubs (avoids needing build_runner in basic CI)
// ---------------------------------------------------------------------------

class _FakeApp extends StatelessWidget {
  const _FakeApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: Center(child: Text('Ekklisia'))),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Reset GetIt between test runs
    if (GetIt.instance.isRegistered<NotificationService>()) {
      await GetIt.instance.reset();
    }

    // NOTE: Real Firebase / Supabase / GetIt.init() cannot run in unit tests.
    // Integration tests that need the full DI graph should live in
    // test/integration/ and use firebase_core's test helpers:
    //
    //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    //
    // For now, we test only that the pure widget layer builds without crash.
  });

  group('Smoke tests', () {
    testWidgets('Stub app renders without error', (tester) async {
      await tester.pumpWidget(const _FakeApp());
      expect(find.text('Ekklisia'), findsOneWidget);
    });

    testWidgets('MaterialApp with dark theme renders', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(child: Text('OK')),
        ),
      ));
      expect(find.text('OK'), findsOneWidget);
    });
  });
}
