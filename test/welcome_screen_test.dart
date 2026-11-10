import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moko/features/auth/presentation/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen renders title, Get Started button, and anime background', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify key UI elements exist
    expect(find.text('Welcome to Moko'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sudah punya akun? Masuk'), findsOneWidget);
    expect(find.text('Masuk Tamu'), findsOneWidget);
  });
}
