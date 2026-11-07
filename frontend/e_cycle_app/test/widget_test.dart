import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_cycle_app/main.dart';
import 'package:e_cycle_app/providers/auth_provider.dart';

void main() {
  testWidgets('E-Cycle app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const ECycleApp(),
      ),
    );

    expect(find.byType(ECycleApp), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
