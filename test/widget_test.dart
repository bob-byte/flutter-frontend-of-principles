import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:principles_app/app/app.dart';
import 'package:principles_app/views/startup_view.dart';
import 'package:principles_app/views/common/app_loading_indicator.dart';

void main() {
  testWidgets('App boots startup screen without post-splash spinner', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PrinciplesApp());
    expect(find.byType(StartupView), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsNothing);
  });
}
