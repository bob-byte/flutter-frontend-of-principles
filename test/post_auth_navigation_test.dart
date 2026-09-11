import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/app/post_auth_navigation.dart';
import 'package:principles_app/views/helper_view.dart';

void main() {
  testWidgets('openPostAuthShell clears pre-auth routes under the shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const Scaffold(body: Text('startup')),
          '/login': (_) => const Scaffold(body: Text('login')),
          HelperView.routeName: (_) => const Scaffold(body: Text('shell')),
        },
        initialRoute: '/',
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/login');
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);

    openPostAuthShell(navigator);
    await tester.pumpAndSettle();

    expect(find.text('shell'), findsOneWidget);
    expect(find.text('login'), findsNothing);
    expect(find.text('startup'), findsNothing);
    expect(navigator.canPop(), isFalse);
  });
}
