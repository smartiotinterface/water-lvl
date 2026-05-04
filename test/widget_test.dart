// test/widget_test.dart
// Smoke tests for SmartIoT — validates LoginScreen renders and toggles correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_iot_interface/services/auth_service.dart';
import 'package:smart_iot_interface/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders key elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>(
        create: (_) => AuthService(),
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // App title
    expect(find.text('Smart IoT Interface'), findsOneWidget);
    // Default sign-in subtitle
    expect(find.text('Sign in to continue'), findsOneWidget);
    // Email & password fields present
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
  });

  testWidgets('LoginScreen toggles between Sign In and Register',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>(
        create: (_) => AuthService(),
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initially shows Sign In
    expect(find.text('Sign In'), findsWidgets);

    // Tap Register toggle
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    // Should now show Create Account mode
    expect(find.text('Create a new account'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
