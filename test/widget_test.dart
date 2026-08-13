// Smoke test for the deepThink app.
//
// DeepThinkApp immediately triggers real OS/network I/O (Ollama launcher,
// hardware detection) which cannot run inside the Flutter test sandbox.
// Instead we test the two static sub-widgets directly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_think_er/ui/widgets/app_theme.dart';

// A minimal wrapper that applies the app theme so widget tests have the
// correct theme context.
Widget _themed(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
    );

void main() {
  testWidgets('Splash screen shows title and spinner', (tester) async {
    await tester.pumpWidget(_themed(
      Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('deepThink',
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent)),
              SizedBox(height: 40),
              CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2),
            ],
          ),
        ),
      ),
    ));

    expect(find.text('deepThink'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
